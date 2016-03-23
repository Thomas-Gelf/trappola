
package Trappola::Daemon;
use Trappola::Log;
use base 'Exporter';
our @EXPORT = qw/ /;

use Time::HiRes qw( usleep );

sub new {
    my $class = shift;
    die 'No pid file given' unless $_[0];
    my $self = {};
    bless $self, $class;
    $self->{'foreground'} = 0;
    $self->{'pidfile'} = $_[0];
    $self->{'user'} = $_[1];
    $self->_initialize();
    return $self;
}

sub _initialize {
    my $self = shift;
}

sub foreground {
    $_[0]->{'foreground'} = 1;
}

sub init {
    my %config = %{ $_[0] };
    my $name    = $config{'name'} || die("Daemon is missing the 'name' parameter");
    my $pidfile = $config{'pid_file'} || die("Daemon is missing the 'pid_file' parameter");
    my $code    = $config{'code'};
    my $user    = $config{'user'};
    my $daemon  = new Trappolo::Daemon($pidfile, $user);
    # $daemon->foreground();
    Log->setLogName($name);
    if (defined ($ARGV[0]) && $ARGV[0] eq 'start') {
        $0 = $name;
        eval {
            $daemon->daemonize();
            1;
        } or do {
            my $err = $@;
            Log->err("$name failed: " . $err);
            die("Daemonizing failed: " . $err);
        };
        if ($code) {
            Log->info('Running code');
            eval {
                $code->();
                1;
            } or do {
                Log->err("$name failed: " . $@);
            };
            Log->info('Code finished');
        }
        exit 0;
    } elsif (defined ($ARGV[0]) && $ARGV[0] eq 'status') {
        if (my $pid = $daemon->isRunning()) {
            print "$name is running with PID $pid\n";
            exit 0;
        } else {
            print "$name is not running\n";
            exit 3;
        }
    } elsif (defined ($ARGV[0]) && $ARGV[0] eq 'stop') {
        if (my $pid = $daemon->isRunning()) {
            $daemon->stop();
            print "$name running with PID $pid has been stopped\n";
        } else {
            print "$name is not running\n";
        }
        exit 0;
    } else {
        printf "USAGE: %s start|stop|status\n", $name;
        exit 7;
    }

}

sub isRunning {
    my $self = shift;
    if (-e $self->{'pidfile'}) {
        -r $self->{'pidfile'} or die "Existing PID file $self->{'pidfile'} is not readable";
        open my $PID, $self->{'pidfile'};
        my $old_pid = <$PID>;
        chomp $old_pid;
        die "Invalid PID found: $old_pid" unless $old_pid =~ /^\d+$/;
        close $PID;
        return $old_pid if $self->pidIsAlive($old_pid);
        unlink $self->{'pidfile'};
        print "WARNING: Removed orphaned PID file $self->{'pidfile'} left by PID $old_pid\n";
        Log->warn("Removed orphaned PID file $self->{'pidfile'} left by PID $old_pid");
    }
    return 0;
}

sub pidIsAlive {
    my $self = shift;
    my $pid = shift;
    return 1 if kill 0, $pid;
}

sub stop {
    my $self = shift;
    my $pid;
    if (shift) {
        Log->info("Shutting down right now");
        unlink $self->{'pidfile'};
        exit 0;
    } else {
        return 1 unless $pid = $self->isRunning();
        Log->info("Shutting down process with PID $pid");
        my $wait = 1;
        my $timeout = 30;
        my $start = time();
        while ($wait) {
            kill 15, $pid;
            if ($self->pidIsAlive($pid)) {
                usleep(100000);
                $wait = 0 if (time() > $timeout + $start);
            } else {
                unlink $self->{'pidfile'};
                return 1;
            }
        }
        print "Process with PID $pid did not terminate in time, sending KILL signal\n";
        kill -9, $pid;
    }
}

sub daemonize {
    use POSIX qw(setsid);
    use File::Basename;
    my $self = shift;
    my $pid;
    my $old_pid;

    if ($self->{'user'}) {
        my ($login, $pass, $uid, $gid) = getpwnam($self->{'user'});
        if (! $login) {
            die(sprintf("Unable to get user information: %s\n", $self->{'user'}));
        }
        $) = $gid;
        $) = $gid;
        $< = $uid;
        $> = $uid;
    }
    die(sprintf("Cannot write to pidfile %s\n", $self->{'pidfile'})) unless -w dirname($self->{'pidfile'});

    if ($old_pid = $self->isRunning()) {
        print "Daemon is already running with PID $old_pid\n";
        exit 0;
    }

  chdir '/tmp' or die "Can't chdir to /tmp: $!";
    umask 0;

    if ($self->{'foreground'}) {
        $pid = $$;
    } else {
        Log->disableStdout();
        my $pid = fork;
        if ($pid) {
            Log->info('Successfully forked PID ' . $pid);
            printf("Successfully forked PID %d\n", $pid);
            exit 0;
        }
        die "Can't fork: $!" if not defined $pid;

        open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
        open STDOUT, '>>/dev/null' or die "Can't write to /dev/null: $!";
        open STDERR, '>>/dev/null' or die "Can't write to /dev/null: $!";
    }

  setsid or die "Can't start a new session: $!";

  open(FH, '>' . $self->{'pidfile'}) || die "Can't write " . $self->{'pidfile'} . ": $!\n";
  print FH $$;
  close(FH);
    Log->info('Running');
  umask 0;
}

1;
