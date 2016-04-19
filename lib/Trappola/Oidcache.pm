package Trappola::Oidcache;

use strict;
use warnings;
use Trappola::TrapOid;
use SNMP;
use NetSNMP::ASN ':all';

my $instance;

sub instance {
    $instance ||= new Trappola::Oidcache(@_);
}

sub new {
    my $class = shift;
    my $db = shift;
    my $self = {
        'cache' => {},
        'db'    => $db
    };
    bless $self, $class;
    $self->initializeMibs;
    $self->fetchPersistedOids;
    return $self;
}

sub db {
    $_[0]->{'db'};
}

sub fetchPersistedOids {
    my $self = shift;
    %{ $self->{'cache'} } = $self->db->fetchObjectHash(
        'Trappola::TrapOid',
        'SELECT oid, short_name, mib_name, description FROM trap_oidcache'
    );
}

sub refreshUnresolvedOids {
    my $self = shift;
    my $db = $self->db;

    $db->execute("DELETE FROM trap_oidcache WHERE short_name LIKE '%.%.%'");

    my $query = 'SELECT o.oid FROM ('
        . ' SELECT DISTINCT oid FROM trap_varbind '
        . ' UNION SELECT DISTINCT oid FROM trap'
        # TODO: only unresolved . " UNION SELECT DISTINCT value FROM trap_varbind WHERE type = 'object_id'"
        . ') o LEFT JOIN trap_oidcache c ON o.oid = c.oid'
        . ' WHERE c.oid IS NULL';
    $query = '
SELECT DISTINCT t.oid FROM trap t LEFT JOIN trap_oidcache c ON t.oid = c.oid WHERE c.oid IS NULL
UNION
SELECT DISTINCT tv.oid FROM trap_varbind tv LEFT JOIN trap_oidcache c ON tv.oid = c.oid WHERE c.oid IS NULL
';

$query = "SELECT t.oid FROM (SELECT DISTINCT oid FROM trap ) t LEFT JOIN trap_oidcache c ON t.oid = c.oid WHERE c.oid IS NULL
UNION
SELECT DISTINCT tv.oid FROM trap_varbind tv LEFT JOIN trap_oidcache c ON tv.oid = c.oid WHERE c.oid IS NULL
UNION
SELECT tv.oid FROM (SELECT DISTINCT value AS oid FROM trap_varbind WHERE type = 'object_id') tv LEFT JOIN trap_oidcache c ON tv.oid = c.oid WHERE c.oid IS NULL;
 ";

    my @unresolved = @{ $self->db->fetchCol($query) };
    my $oid;
    my %res;
    foreach $oid (@unresolved) {
        $res{$oid} = $self->lookup($oid);
    }

    $self->persist;

    $db->execute(
        'UPDATE trap t JOIN trap_oidcache c ON t.oid = c.oid'
        . ' SET t.mib_name = c.mib_name, t.short_name = c.short_name,'
        . ' t.message = c.description'
        . " WHERE t.short_name LIKE '%.%.%' AND c.short_name NOT LIKE '%.%.%'"
    );

    return \%res;
}

sub lookup {
    my $self = shift;
    my $oid  = shift;
    my $short_name;
    my $mib_name;
    my $description;

    if (! defined $self->{'cache'}->{$oid}) {
        my $res = SNMP::translateObj($oid, 0, 1);
        if (! defined($res)) {
            $short_name = $oid;
        } else {
            if (index($res, '::') == -1) {
                $short_name = $oid;
            } else {
                ($mib_name, $short_name) = split(/::/, $res, 2);
                $description = $SNMP::MIB{$oid}{'description'};
                $description =~ s/\n\s+/ /g if defined $description;
            }
        }
        $self->{'cache'}->{$oid} = Trappola::TrapOid->create(
            'oid'         => $oid,
            'short_name'  => $short_name,
            'mib_name'    => $mib_name,
            'description' => $description 
        );
    }

    return $self->{'cache'}->{$oid};
}

sub persist {
    my $self = shift;
    my $oid;
    my $obj;

    my $short;
    foreach $oid (keys %{ $self->{'cache'} }) {
        $obj = $self->{'cache'}->{$oid};
        if ($obj->hasBeenModified) {
            $short = $obj->short_name;
# ??
            $self->db->store($obj) unless $short =~ /^enterprises\./;
        }
    }

    $self->db->commit;
    return $self;
}

sub initializeMibs {
    my $self = shift;
    $SNMP::auto_init_mib = 0;
    $SNMP::save_descriptions = 1;
    SNMP::loadModules('ALL');
    #SNMP::loadModules($self->{'config'}->{'mibs'}); # Reihenfolge?
    #$ENV{'MIBS'} = 'ALL ';
    #SNMP::loadModules('ALL');
#&SNMP::initMib();
}

1;
