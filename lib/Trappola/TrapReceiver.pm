
package Trappola::TrapReceiver;

use strict;
use warnings;
use NetSNMP::TrapReceiver;
use Trappola::Trap;
#use Directory::Queue::Simple;
use Sys::Syslog;
use Redis;

our $VERSION = '1.0.0';

# Allows quick setup
sub register {
    return new Trappola::TrapReceiver(@_);
}

sub new {
    my $class = shift;
    my $config = shift;
    my $self = {
        'config' => $config
    };
    bless $self, $class;
    $self->log('info', 'Initializing TrapReceiver');
    $self->initializeQueue();
    $self->registerWithNetSNMP();
    $self->log('info', 'TrapReceiver initialized');
    return $self;
}

sub initializeQueue {
    my $self = shift;
    $self->log('info', 'Ready to set up queue');
    # TODO: Route trap to different configurable spool directories
#    my $qdir = $self->config(
#        'global',
#        'spool_directory',
#        '/var/spool/trappola/queue'
#    );
#    $self->log('info', 'Preparing queue at %s', $qdir);
#    $self->{'dirq'} = Directory::Queue::Simple->new(path => $qdir);
#    $self->{'dirq'}->purge();
    $self->log('info', 'Preparing redis queue');
 $self->{'redis'} = Redis->new(server => 'icingaweb:6379');
}

sub config {
    return shift->{'config'}->get(@_);
}

sub log {
    my $self = shift;
    my $level = shift;
    my $message = '[trappola] ' . sprintf shift, @_;
    syslog($level, $message);
    return $self;
}

sub registerWithNetSNMP {
    my $self = shift;
    NetSNMP::TrapReceiver::register('all', sub { $self->receive(@_) } )
        || die("failed to register our perl trap handler");
    $self->log('info', 'Embedded trap handler loaded successfully');
}

sub receive {
    my $self = shift;
    my $pdu_info = $_[0];
    my $varbinds = $_[1];
    my ($from, $to, $from_port, $to_port, $proto);
    my ($community, $securityEngineID, $securityName);
    $self->log('err', 'Got a trap');

    eval {
        my $trap = Trappola::Trap::fromNetSnmp(@_);
        # my $name = $self->{'dirq'}->add($trap->serialize);
        my $name = $self->{'redis'}->lpush('Trap::queue', $trap->serialize);
        $self->log('debug', 'Added Trap as %s', $name);
    1;
    } or do {
        my $e = $@;
        $self->log('err', 'Failed to parse trap: ' . $e);
    };

    return NETSNMPTRAPD_HANDLER_OK;

  # NETSNMPTRAPD_HANDLER_OK
  #   Handling the trap succeeded, but lets the snmptrapd demon check for further appropriate handlers.
  # NETSNMPTRAPD_HANDLER_FAIL
  #   Handling the trap failed, but lets the snmptrapd demon check for further appropriate handlers.
  # NETSNMPTRAPD_HANDLER_BREAK
  #   Stops evaluating the list of handlers for this specific trap, but lets the snmptrapd demon apply global handlers.
  # NETSNMPTRAPD_HANDLER_FINISH
  #   Stops searching for further appropriate handlers.
}

1;

