package Trappola::Trap;

use strict;
use warnings;

use base 'DataObject';
use POSIX qw(strftime);
use JSON;
use Trappola::TrapVarbind;

our $keyIsAutoInc = 1;

our $table = 'trap';

our %defaultProperties = (
    id               => undef,
    listener_id      => undef,
    timestamp        => undef,
    host_name        => undef,
# TODO sender_address (src = evtl forwarder)

    src_address      => undef,
    src_port         => undef,
    dst_address      => undef,
    dst_port         => undef,
    network_protocol => 'ipv4',
    auth             => undef,
    message          => undef,
    type             => undef,
    version          => undef,
    requestid        => undef,
    transactionid    => undef,
    messageid        => undef,
    oid              => undef,
    mib_name         => undef,
    short_name       => undef,
    transport        => undef,
    sys_uptime       => undef,
    security         => undef,
    v3_sec_level     => undef,
    v3_sec_name      => undef,
    v3_sec_engine    => undef,
    v3_ctx_name      => undef,
    v3_ctx_engine    => undef
);

my %mapVersions = (
    0 => 'v1',
    1 => 'v2c',
    3 => 'v3',
);

my %mapSecurityLevels = (
    1 => 'noAuthNoPriv',
    2 => 'authNoPriv',
    3 => 'authPriv'
);

my %mapSecurityModels = (
    1 => 'v1',
    2 => 'v2c',
    3 => 'usm '
);

my %mapV3 = (
    'securitymodel'    => 'security',
    'securityName'     => 'v3_sec_name',
    'securitylevel'    => 'v3_sec_level',
    'securityEngineID' => 'v3_sec_engine',
    'contextName'      => 'v3_ctx_name',
    'contextEngineID'  => 'v3_ctx_engine',
);

my %types = (
    1 =>     'boolean',   # ASN_BOOLEAN
    2 =>     'integer',   # ASN_INTEGER
    3 =>     'bit_str',   # ASN_BIT_STR
    4 =>   'octet_str',   # ASN_OCTET_STR
    5 =>        'null',   # ASN_NULL
    6 =>   'object_id',   # ASN_OBJECT_ID
    # ASN_APPLICATION => 'application', # == OBJECT_ID?

    16 =>    'sequence',    # ASN_SEQUENCE
    17 =>         'set',         # ASN_SET
    64 =>   'ipaddress',   # ASN_IPADDRESS
    65 =>     'counter',     # ASN_COUNTER
    66 =>    'unsigned',    # ASN_UNSIGNED
    # ASN_GAUGE       => 'gauge',       # == UNSIGNED? (32bit)
    67 =>   'timeticks',   # ASN_TIMETICKS
    68 =>      'opaque',      # ASN_OPAQUE
    70 =>   'counter64',   # ASN_COUNTER64
    72 =>       'float',       # ASN_FLOAT
    73 =>      'double',      # ASN_DOUBLE
    74 =>   'integer64',   # ASN_INTEGER64
    75 =>  'unsigned64'   # ASN_UNSIGNED64
);

sub fromNetSnmp {
    my %info     = %{ $_[0] }; # PDU info
    my @varbinds = @{ $_[1] }; # Variable bindings

    my $key;
    my $oid;
    my $value;
    my $type;
    my $varbind;

    my $trap = Trappola::Trap->create();
    $trap->version($mapVersions{$info{'version'}});
    $trap->type(lc $info{'notificationtype'}) if defined $info{'notificationtype'};
    $trap->timestamp(strftime '%Y-%m-%d %H:%M:%S', localtime);
    $trap->parseReceivedFrom($info{'receivedfrom'});

    foreach $key ('messageid', 'transactionid', 'requestid') {
        $trap->$key($info{$key}) if defined $info{$key};
    }
    # errorstatus, errorindex ?
    if ($trap->version eq 'v3') {
        $trap->security('usm');
        foreach $key (keys %mapV3) {
            $trap->set($mapV3{$key}, $info{$key}) if defined $info{$key};
        }
        $trap->auth($trap->v3_sec_name);
    } else {
        $trap->security($trap->version);
        $trap->auth($info{'community'}) if $info{'community'};
    }

    foreach $varbind (@varbinds) {
        ($oid, $value, $type) = @$varbind;
        $oid = "$oid";
        if ($oid eq '.1.3.6.1.2.1.1.3.0') {
            if ($value =~ /^\d+$/) {
                $trap->sys_uptime(int($value / 100));
            } else {
                # Invalid sys uptime?
            }
        } elsif ($oid eq '.1.3.6.1.6.3.1.1.4.1.0') {
            $trap->oid($value);
        } else {
            if ($type == 4) {
                $value =~ s/^"(.*)"$/$1/;
            }

            $trap->addVarbind($oid, $value, $trap->getTypeName($type));
        }
        if ($oid eq '.1.3.6.1.6.3.18.1.3.0') {
            # forwarder. Doesn't work?
            $trap->src_address($value);
        }
    }

    return $trap;
}

sub addVarbind {
    my $self = shift;
    my $oid = shift;
    my $value = shift;
    my $type = shift;

    $self->{'varbinds'} = {} if not defined $self->{'varbinds'};
    $self->{'varbinds'}->{$oid} = Trappola::TrapVarbind->create(
        'oid'   => $oid,
        'value' => $value,
        'type'  => $type
    );
}

sub getVarbinds {
    return %{ $_[0]->{'varbinds'} };
}

sub bin2hex {
    unpack 'h*', $_[0];
}

sub hex2bin {
    pack 'h*', $_[0];
}

sub parseReceivedFrom {
    my $self = shift;
    my $socket = shift;
    my $from;
    my $to;

    # UDP: [127.0.0.1]:36983->[127.0.0.1]
    # UDP: [10.14.26.60]:33376
    if ($socket =~ /^(\w+):\s*(.+?)(?:-\>(.+?)?)$/) {
        $self->transport(lc $1); # UDP
        $from = $2;
        $to   = $3;

        if ($from =~ s/:(\d+)$//) {
            $self->src_port(int($1));
        }
        $from =~ s/^\[(.+)\]/$1/;
        $self->src_address($from);
        
        if ($to =~ s/:(\d+)$//) {
            $self->dst_port(int($1));
        }
        $to =~ s/^\[(.+)\]/$1/;
        $self->dst_address($to);
    }
}

sub serialize {
    my $self = shift;
    my %props = $self->getProperties;
    my $key;
    my %json = ( 'varbinds' => [] );
    my $out = '';
    foreach $key (sort keys %props) {
        next unless defined($props{$key});
# TODO: prefix base64, also encode existing strings with that prefix
        if ($key eq 'v3_sec_engine' or $key eq 'v3_ctx_engine') {
            $out .= sprintf("%s: %s\n", $key, bin2hex($props{$key}));
            $json{$key} = bin2hex($props{$key});
        } else {
            $out .= sprintf("%s: %s\n", $key, $props{$key});
            $json{$key} = $props{$key};
        }
    }
    $out .= "VARBINDS:\n";
    my %varbinds = $self->getVarbinds;

    foreach my $var (values %varbinds) { 
#        my ($oid, $val, $type) = @{ $x };
        $out .= sprintf "%s %s %s\n", $var->oid, $var->type, escapeValue($var->value);
        push @{ $json{'varbinds'} }, {
            'oid'   => $var->oid,
            'type'  => $var->type,
            'value' => $var->value
        };
    }

    return to_json(\%json);
    $out .= "\n";
    return $out;
}

sub fromSerialization {
    my $in = shift;
    my $oidcache = shift;
    my $gotHeader = 0;
    my $trap = Trappola::Trap->create();
    my $fromJson = from_json($in);
    foreach my $key (keys $fromJson) {
        my $value = $fromJson->{$key};
        if ($key eq 'varbinds') {
            foreach my $varbind (@{ $value }) {
                $oidcache->lookup($varbind->{'oid'});
                $trap->addVarbind(
                    $varbind->{'oid'},
                    unescapeValue($varbind->{'value'}),
                    $varbind->{'type'}
                );
                if ($varbind->{'type'} eq 'object_id') {
                    $oidcache->lookup($varbind->{'value'});
                }
            }
        } else {
            if ($key eq 'v3_sec_engine' or $key eq 'v3_ctx_engine') {
                $trap->$key(hex2bin($value));
            } else {
                $trap->$key($value);
            }
        }
    }

    my $oid = $oidcache->lookup($trap->oid);
#use Data::Dumper;
#print Dumper($oid);
    $trap->mib_name($oid->mib_name);
    $trap->short_name($oid->short_name);
    $trap->message($oid->description); # Really? Length?

    return $trap;


    my (
#$oid, 
$key, $type, $value, $line);
    my @lines = split /\n/, $in;
    foreach $line (@lines) {

        if ($gotHeader) {
            ($oid, $type, $value) = split / /, $line, 3;
            #$cache->lookup($oid);
            $oidcache->lookup($oid);
            $trap->addVarbind($oid, unescapeValue($value), $type);
            next;
        }
        if ($line eq 'VARBINDS:') {
            $gotHeader = 1;
        } else {
            ($key, $value) = split /: /, $line;
            if ($key eq 'v3_sec_engine' or $key eq 'v3_ctx_engine') {
                $trap->$key(hex2bin($value));
            } else {
                $trap->$key($value);
            }
        }
    }
    $oid = $oidcache->lookup($trap->oid);
    $trap->mib_name($oid->mib_name);
    $trap->short_name($oid->short_name);
    $trap->message($oid->description); # Really? Length?
    return $trap;
}

sub fromLegacySerialization {
    my $in = shift;
    my $oidcache = shift;
    my $gotHeader = 0;
    my $trap = Trappola::Trap->create();
    my $message;
    my ($oid, $key, $type, $value, $line);
    my @lines = split /\n/, $in;
    foreach $line (@lines) {

        if ($gotHeader) {
            ($oid, $type, $value) = split / /, $line, 3;
            #$cache->lookup($oid);
            $oidcache->lookup($oid);
            $trap->addVarbind($oid, unescapeLegacyValue($value), $trap->getTypeName($type));

if ($oid eq '.1.3.6.1.6.3.1.1.4.1.0') {
    $trap->oid($value);
}
#if ($oid eq '.1.3.6.1.4.1.111.15.3.1.1.24.1') {
#    $trap->host_name(unescapeLegacyValue($value));
#}
#
#if ($oid eq '.1.3.6.1.4.1.111.15.3.1.1.3.1') {
#    $message = unescapeLegacyValue($value);
#}
#oraEMNGEventMessage
            next;
        }
        if ($line eq 'VARBINDS:') {
            $gotHeader = 1;
        } else {
            ($key, $value) = split /: /, $line;

            $key = 'transport' if $key eq 'protocol';
            $key = 'auth' if $key eq 'community';
            $key = 'dst_address' if $key eq 'to';
            $key = 'dst_port' if $key eq 'to_port';
            $key = 'src_port' if $key eq 'from_port';
            if ($key eq 'from') {
                if ($value =~ /^(.+?)\]\:(\d+)\-\>\[(.+?)$/) {
                    my ($src_address, $src_port, $dst_address) = ($1, $2, $3);
                    $trap->src_address($src_address);
                    $trap->src_port($src_port);
                    $trap->dst_address($dst_address);
                } else {
                    $trap->src_address($value);
                }
            } elsif ($key eq 'v3_sec_engine' or $key eq 'v3_ctx_engine') {
                $trap->$key(hex2bin($value));
            } else {
                $trap->$key($value);
            }
        }
    }
    $oid = $oidcache->lookup($trap->oid);
$trap->security('v2c');
$trap->type('trap');
    $message ||= $oid->description;
    $trap->mib_name($oid->mib_name);
    $trap->short_name($oid->short_name);
    $trap->message($message); # Really? Length?
    return $trap;
}

sub unescapeValue {
    my $value = shift;
    $value =~ s/\\n/\n/g;
    $value =~ s/\\r/\r/g;
    $value =~ s/\\t/\t/g;
    return $value;
}

sub unescapeLegacyValue {
    my $value = shift;
    $value =~ s/\\n/\n/g;
    $value =~ s/\\r/\r/g;
    $value =~ s/\\t/\t/g;
    $value =~ s/^"//g;
    $value =~ s/"$//g;
    $value =~ s/\\"/"/g;
   return $value;
}

sub escapeValue {
    my $value = shift;
    # Automatic: " -> \" ??
    $value =~ s/\n/\\n/g;
    $value =~ s/\r/\\r/g;
    $value =~ s/\t/\\t/g;
    return $value;
}

sub getTypeName {
    my $self = shift;
    my $type = shift;
    return $types{$type} if defined $types{$type};
    return 'unknown';
}


1;

