#!/usr/bin/perl -w

use strict;
use warnings;

package Trappola::QueueReader;

use base 'Exporter';
use Directory::Queue::Simple;
use Time::HiRes qw( usleep );

our $VERSION = '1.0.0';

sub new {
    my $class = shift;
    my $self = {
      'directory' => shift,
      'idleruns' => 0
    };
    bless $self, $class;
    $self->prepareQueue();
    return $self;
}

sub prepareQueue {
    my $self = shift;
   $self->{'queue'} = Directory::Queue::Simple->new(
        path => $self->{'directory'}
    );
    # Remove useless old directories:
    $self->{'queue'}->purge();
}

sub pop {
    my $self = shift;
    my $name;
    my $data;
    my $queue = $self->{'queue'};

    while (1) {
        for ($name = $queue->first(); $name; $name = $queue->next()) {
            if (! $queue->lock($name)) {
                # Log->debug('Waiting for locked queue');
                usleep(100000);
                next;
            }
            # Log->debug('Reading queue file %s', $name);
            $data = $queue->get($name);
            # one could use unlock($name) to only browse the queue...
            # In an ideal world file would be handled before removal. This used
            # to be handleTrap($data) before queue->remove($name)
            $queue->remove($name);
            return $data;
        }
        usleep(100000);
        $self->{'idleruns'}++;
        if ($self->{'idleruns'} > 60) {
            $self->{'idleruns'} = 0;
            $self->{'queue'}->purge();
        }
    }
}

1;

