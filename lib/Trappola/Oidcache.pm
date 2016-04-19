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
