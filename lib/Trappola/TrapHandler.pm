#!/usr/bin/perl -w

package Trappola::TrapHandler;

use strict;
use warnings;
use Redis;
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
    my ($trap, $list, $value);
    my $redis = $self->redis;
    while (1) {
        ($list, $value) = $redis->brpop($redis, 'Trappola::queue', 3);
        if (not defined $list) {
            print "Got nothing for 3 secs\n";
            next;
        }

        $trap = Trappola::Trap::fromSerialization($value, $self->{'oidcache'});
        $self->handleTrap($trap);
    }
}

# Compat only, to be removed soon
sub dispatchLegacyLoop {
    my $self = shift;
    my $trap;

    my $fh;
    open($fh, '|/usr/bin/env icingacli trappola trap receive');

    while (1) {
        print $fh $self->readFromLegacyQueue->serialize . "\n";
        #$self->handleTrap($self->readFromLegacyQueue);
    }
    close $fh;
}

sub handleTrap {
    my $self = shift;
    my $trap = shift;
    my $fh;

    ## TODO: keep it open, eventually re-fork from time to time
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

# Compat only, to be removed soon
sub readFromLegacyQueue {
    my $self = shift;
    my $serialized = $self->{'queue'}->pop();
    # print $serialized;
    return Trappola::Trap::fromLegacySerialization($serialized, $self->{'oidcache'});
}

# Compat only, to be removed soon
sub readFromQueue {
    my $self = shift;
    my $serialized = $self->{'queue'}->pop();
    # print $serialized;
    return Trappola::Trap::fromSerialization($serialized, $self->{'oidcache'});
}

## Todo: externalize Redis, this is duplicated code
sub redis {
    my $self = shift;
    unless ($self->{'redis'}) {
        $self->connectToRedis();
    }

    return $self->{'redis'};
}

sub connectToRedis {
    my $self = shift;
    eval {
        my $redisHost = $self->config(
            'redis',
            'host',
            'localhost'
        );

        my $redisPort = $self->config(
            'redis',
            'port',
            '6379'
        );

        my $socket = sprintf('%s:%d', $redisHost, $redisPort);

        $self->{'redis'} = Redis->new(
            server    => $socket,
            reconnect => 2_592_000, # Give up after 30 days
            every     => 1_000_000
        );
        $self->log('info', 'Successfully connected to Redis at ' . $socket);
        1;
    } or do {
        my $e = $@;
        $self->log('err', 'Failed to connect to Redis: ' . $e);
    };
}

1;
