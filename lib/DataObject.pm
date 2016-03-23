package DataObject;

use strict;
use warnings;

use Data::Dumper;

our $table;

our %defaultProperties;

our $keyIsAutoInc = 1;

sub create {
   my $class = shift;
   new $class @_;
}

sub fromDb {
   my $class = shift;
   my $self = new $class @_;
   $self->setUnmodified;
   $self->{'fromDb'} = 1;
   return $self;
}

sub hasBeenLoadedFromDb {
    return $_[0]->{'fromDb'};
}

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    my %params;
    if (scalar @_ == 1 && $_[0] =~ /^HASH/) {
        %params = %{$_[0]};
    } else {
        %params = @_;
    }
    $self->{'props'} = \%{{ (%{{ $self->defaultProperties }}, %params) }};
    $self->{'fromDb'} = 0;
    $self->setNew;
    return $self;
}

sub setNew {
    my $self = shift;
    my $key;
    $self->{'modified'} = {};
    foreach $key (keys %{ $self->{'props'} }) {
        $self->{'modified'}->{ $key } = 1;
    }
    if ($self->doesAutoInc) {
        $self->{'modified'}->{ $self->getKeyColumn } = 0;
    }
    $self->{'hasBeenModified'} = 1;
}

sub setUnmodified {
    my $self = shift;
    my $key;
    $self->{'modified'} = {};
    foreach $key (keys %{ $self->{'props'} }) {
        $self->{'modified'}->{ $key } = 0;
    }
    $self->{'hasBeenModified'} = 0;
}

sub getProperties {
    my $self = shift;
    return %{ $self->{'props'} };
}

sub getModifiedProperties {
    my $self = shift;
    my (%modified, $key);
    
    foreach $key (keys %{ $self->{'modified'} }) {
        next unless $self->{'modified'}->{$key};
        $modified{$key} = $self->{'props'}->{$key};
    }
    return %modified;
}

sub propertySetModified {
    my $self = shift;
    my $key = shift;
    $self->{'modified'}->{$key} = 1;
    $self->{'hasBeenModified'} = 1;
}

sub hasBeenModified {
    return $_[0]->{'hasBeenModified'};
}

sub getKeyColumn {
    return 'id';
}

sub getKey {
    return $_[0]->get($_[0]->getKeyColumn);
}

sub setKey {
    my $self = shift;
    $self->set($self->getKeyColumn, shift);
    return $self;
}

sub assertPropertyExists {
    die(sprintf('"%s" is not a valid property for "%s"', $_[1], ref $_[0])) unless $_[0]->has($_[1]);
}

sub get {
    $_[0]->assertPropertyExists($_[1]);
    return $_[0]->{'props'}->{$_[1]};
}

sub has {
    return exists $_[0]->{'props'}->{$_[1]};
}

sub set {
    my $self = shift;
    my $key  = shift;
    my $val  = shift;
    $self->assertPropertyExists($key);
    return if (! defined $self->{'props'}->{$key}) && (! defined $val);
    if (defined $val && ! ($val =~ m/^\d+$/)) {
        # $val = chomp($val);
        $val =~ s/\s+$//m;
        $val =~ s/^\s+//m;
    }

    return if defined $self->{'props'}->{$key} && defined $val && $val eq $self->{'props'}->{$key};
    # print "Setting $key\n";
    # print Dumper($self->{'props'}->{$key});
    # print Dumper($val);
    $self->{'props'}->{$key} = $val;
    $self->propertySetModified($key);
}

sub defaultProperties {
    my $self = shift;
    {
        no strict 'refs';
        return %{ ref($self) . '::defaultProperties' };
    }
}

sub getTable {
    my $self = shift;
    {
        no strict 'refs';
        return ${ ref($self) . '::table' };
    }
}

sub doesAutoInc {
    my $self = shift;
    {
        no strict 'refs';
        return ${ ref($self) . '::keyIsAutoInc' };
    }
}

sub AUTOLOAD {
    my $self  = shift;
    our $AUTOLOAD;

    ( my $method = lc $AUTOLOAD ) =~ s/.*:://;
    $self->set($method, shift) if @_;
    return $self->get($method);
}

sub DESTROY {

}

1;
