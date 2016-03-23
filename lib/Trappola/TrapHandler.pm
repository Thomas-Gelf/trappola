#!/usr/bin/perl -w

package Trappola::TrapHandler;

use strict;
use warnings;
use Trappola::Trap;
use Trappola::Oidcache;

require Exporter;

our $VERSION = '1.0.0';

sub new {
    my $class = shift;

    my $self = {
        'db'    => shift,
        'queue' => shift
    };
    $self->{'oidcache'} = new Trappola::Oidcache($self->{'db'});

    bless $self, $class;
}

sub oidCache {
    return $_[0]->{'oidcache'};
}

sub dispatchMainLoop {
    my $self = shift;
    my $trap;
    while (1) {
        $self->handleTrap($self->readFromQueue);
    }
}

sub dispatchLegacyLoop {
    my $self = shift;
    my $trap;

    my $fh;
    open($fh, '|/usr/bin/env icingacli trappola trap receive');

    while (1) {
        print $fh $self->readFromLegacyQueue->serialize . "\n";
        # $self->handleTrap($self->readFromLegacyQueue);
    }
    close $fh;
}

sub handleTrap {
    my $self = shift;
    my $trap = shift;
    my $fh;
        open($fh, '|/usr/bin/env icingacli trappola trap receive');
    print $fh $trap->serialize . "\n";
    close $fh;
return;

    eval {

        $self->{'db'}->store($trap);
        $self->{'oidcache'}->persist;

        open($fh, '|/usr/bin/env icingacli trappola trap receive');
        my %varbinds = $trap->getVarbinds;
        foreach my $var (values %varbinds) {
            $var->trap_id($trap->id);
            $self->{'db'}->store($var);
        }

        $self->{'db'}->commit;   # commit the changes if we get this far
    };
    if ($@) {
        warn "Transaction aborted because $@";
        # now rollback to undo the incomplete changes
        # but do it in an eval{} as it may also fail
        eval { $self->{'db'}->rollback };
        # add other application on-error-clean-up code here
    }

    print $fh $trap->serialize . "\n";
    close $fh;
}

sub readFromLegacyQueue {
    my $self = shift;
    my $serialized = $self->{'queue'}->pop();
    # print $serialized;
    return Trappola::Trap::fromLegacySerialization($serialized, $self->{'oidcache'});
}

sub readFromQueue {
    my $self = shift;
    my $serialized = $self->{'queue'}->pop();
    # print $serialized;
    return Trappola::Trap::fromSerialization($serialized, $self->{'oidcache'});
}

1;
