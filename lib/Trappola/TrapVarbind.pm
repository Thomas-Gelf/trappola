package Trappola::TrapVarbind;

use strict;
use warnings;

use base 'DataObject';

our %defaultProperties = (
    trap_id => undef,
    oid	    => undef,
    type    => undef,
    value   => undef
);

our $table = 'trap_varbind';

our $keyIsAutoInc = 0;

sub getKeyColumn {
    return ('trap_id', 'oid');
}

1;
