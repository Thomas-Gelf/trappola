package Trappola::TrapOid;

use strict;
use warnings;

use base 'DataObject';

our %defaultProperties = (
    oid         => undef,
    short_name  => undef,
    mib_name    => undef,
    description => undef
);

our $table = 'trap_oidcache';

our $keyIsAutoInc = 0;

sub getKeyColumn {
    return 'oid';
}

1;
