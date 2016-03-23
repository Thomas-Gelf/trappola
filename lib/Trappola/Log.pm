
package Trappola::Log;
use base 'Exporter';

our @EXPORT = qw/ Log /;
our $VERSION = '1.0.0';
my $instance;

sub instance {
    $instance ||= new Trappola::Log;
}

sub new {
    my $class = shift;
    my $self = {
        'config' => shift
    };
    bless $self, $class;
    $self->{'config'} = {
        'syslog_enabled' => 1,
        'stdout_enabled' => 0,
        'syslog_opened'  => 1,
        # 'logname'         => 'ICINGA',
        # 'syslog_facility' => 'local0',
    };
    if ($self->{'config'}->{'syslog_enabled'}) {
        $self->openSyslog();
    };

    $self->setLogName($self->{'config'}->get('logname'} ||= 'trappolo');
    return $self;
}

sub openSyslog {
    my $self = shift;
    use Sys::Syslog;
    if ($self->{'syslog_opened'}) {
        closelog();
    }
    openlog(
        $self->getLogName(),
        'ndelay,pid',
        $self->getFacility()
    );
#    syslog('info', 'Log opened');
    $self->{'syslog_opened'} = 1;    
}

sub getFacility {
    my $self = shift;
    $self->{'config'}->get('logging', 'facility', 'local0');
}

sub getLogName {
    my $self = shift;
    $self->{'config'}->get('global', 'application', 'trappola');
}

sub setLogName {
    my $self = shift;
    $self->{'config'}->{'logname'} = $_[0];
    $self->openSyslog() if $self->{'config'}->{'syslog_enabled'};
    return $self;
}

sub log {
    my $self = shift;
    my $level = shift;
    my $message = sprintf shift, @_;
    if ($self->{'config'}->{'syslog_enabled'}) {
        syslog($level, $message);
    }

    if ($self->{'config'}->{'stdout_enabled'}) {
        printf "[%s] %s: %s\n",
            uc($level),
            $self->{'config'}->{'logname'},
            $message;
    }
    return $self;
}

sub enableSyslog {
    my $self = shift;
    $self->{'config'}->{'syslog_enabled'} = 1;
    $self->openSyslog();
    return $self;
}

sub disableSyslog {
    my $self = shift;
    $self->{'config'}->{'syslog_enabled'} = 0;
    return $self;
}

sub enableStdout {
    my $self = shift;
    $self->{'config'}->{'stdout_enabled'} = 1;
    return $self;
}

sub disableStdout {
    my $self = shift;
    $self->{'config'}->{'stdout_enabled'} = 0;
    return $self;
}

sub Log {
    instance();
}

sub debug {
    return shift->log('debug', @_);
}

sub info {
    return shift->log('info', @_);
}

sub warn {
    return shift->log('warning', @_);
}

sub err {
    return shift->log('err', @_);
}

sub crit {
    return shift->log('crit', @_);
}

1;
