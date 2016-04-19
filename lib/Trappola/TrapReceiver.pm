
package Trappola::TrapReceiver;

use strict;
use warnings;
use NetSNMP::TrapReceiver;
use Trappola::Trap;
use Sys::Syslog;
use Redis;

our $VERSION = '1.0.0';

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

sub initializeQueue {
    my $self = shift;
    $self->log('info', 'Ready to set up queue');
    $self->redis;
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
    my $redis = $self->redis;
    unless ($redis) {
        $self->log('err', 'Cannot handle trap, Redis is not available');
        return NETSNMPTRAPD_HANDLER_FAIL;
    }

    eval {
        my $trap = Trappola::Trap::fromNetSnmp(@_);
        my $name = $self->{'redis'}->lpush('Trappola::queue', $trap->serialize);
        $self->log('debug', 'Added Trap as %s', $name);
        1;

    } or do {
        my $e = $@;
        $self->log('err', 'Failed to handle trap: ' . $e);
        return NETSNMPTRAPD_HANDLER_FAIL;
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

