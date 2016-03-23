package Trappola::Config;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT = qw( Config );

my %instances = ();

sub instance {
    my $config_file = shift;
    $instances{$config_file} ||= new Trappola::Config($config_file);
}

sub Config {
    instance(shift);
}

sub new {
    my $class = shift;
    my $config_file = shift;
    my %ini;
    my %config;
    my $self = {
        'config_file' => $config_file,
        'config' => {}
    };
    bless $self, $class;
    $self->parseConfigFile();
}

sub parseConfigFile {
    my $self = shift;
    my $file = $self->{'config_file'};
    die('Cannot read config file: ' . $file) unless -r $file;

    my $line;
    my $fh;

    my $section;
    open $fh, $file;
    while ($line = <$fh>) {
        next if $line =~ /^\s*#/;
        next if $line =~ /^\s*$/;
        if ($line =~ /^\s*\[([^\.]+)\]\s*$/) {
            $section = $1;
            $self->{'config'}->{$section} = {};
            next;
        }
        next unless $section;
        die('Parse error: ' . $line) unless $line =~ /^\s*"?([a-z0-9_]+)"?\s*=\s*(.+)$/;
        $self->{'config'}->{$section}->{$1} = $2;
    }
    return $self;
}

# Usage   : $config->get(<section>, <key>[, <default>])
# Example : $config->get('global', 'timezone', 'UTC');
sub get {
    my $self    = shift;
    my $section = shift;
    my $key     = shift;
    return $self->{'config'}->{$section}->{$key} if defined $self->{'config'}->{$section}->{$key};
    return shift;
}

sub section {
    my $self    = shift;
    my $section = shift;
    return $self->{'config'}->{$section} if defined $self->{'config'}->{$section};
    return shift || {};
}

1;
