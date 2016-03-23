package Trappola::TrapDb;

use strict;
use warnings;

use DBI;
use Module::Load;

# use Socket qw(:DEFAULT);
# use Data::Dumper;

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub store {
    my $self = shift;
    my $obj = shift;
    return 0 unless $obj->hasBeenModified;

    if ($obj->hasBeenLoadedFromDb) {
        $self->updateDataObject($obj);
    } else {
        $self->insertDataObject($obj);
    }
}

sub updateDataObject {
    my $self = shift;
    my $obj = shift;
    my $dbh = $self->db;
    if ($obj->has('mtime')) {
        $obj->mtime(time());
    }
    my %props = $obj->getModifiedProperties;

    my (@params, @cols, $key);

    foreach $key (keys %props) {
        push @cols, sprintf('%s = ?', $key);
        push @params, $props{$key};
    }

    my $sql = sprintf(
        'UPDATE %s SET %s WHERE %s',
        $obj->getTable,
        join(', ', @cols),
        sprintf('%s = ?', $obj->getKeyColumn)
    );
    push @params, $obj->getKey;

    my $sth = $dbh->prepare($sql);
    $sth->execute(@params);
    $obj->setUnmodified;
}

sub insertDataObject {
    my $self = shift;
    my $obj = shift;
    my $dbh = $self->db;

    if ($obj->has('ctime')) {
        $obj->ctime(time);
    }
    if ($obj->has('mtime')) {
        $obj->mtime($obj->ctime);
    }

    my %props = $obj->getModifiedProperties;
    my (@params, @cols, $key);

    foreach $key (keys %props) {
        push @cols, sprintf('%s = ?', $key);
        push @params, $props{$key};
    }

    my $sql = sprintf(
        'INSERT INTO %s SET %s',
        $obj->getTable,
        join(', ', @cols)
    );

    my $sth = $dbh->prepare($sql);
    $sth->execute(@params);
    if ($obj->doesAutoInc) {
       $obj->setKey($dbh->{'mysql_insertid'});
    }
    $obj->setUnmodified;
}

sub fetchHash {
    my $self = shift;
    my $key = shift;
    my $sql = shift;
    my (%result, $row);
    my $sth = $self->execute($sql, @_);

    while ( $row = $sth->fetchrow_hashref ) {
        $result{ $row->{$key} } = $row;
    }
    return %result;    
}

sub fetchObjectHash {
    my $self  = shift;
    my $class = shift;
    load $class;

    my $key   = $class->getKeyColumn;
    my $sql   = shift;
    my (%result, $row);

    my $sth = $self->execute($sql, @_);

    while ( $row = $sth->fetchrow_hashref ) {
        $result{ $row->{$key} } = $class->fromDb(%{ $row });
    }

    return %result;
}

sub execute {
    my $self = shift;
    my (%result, $row);
    my $sql = shift;
    my @params = @_;
    my $dbh = $self->db;
    my $sth = $dbh->prepare($sql);

    if (scalar @params) {
        $sth->execute(@params);
    } else {
        $sth->execute;
    }
    return $sth;
}

sub commit {
    return $_[0]->db->commit;
}


sub db {
    my $self = shift;
    if (! $self->{'dbh'}) {
        $self->connect();
    }
    return $self->{'dbh'};
}

sub connect {
    my $self = shift;
    my $dsn = 'dbi:mysql:database=trappola;host=localhost';
    $dsn = 'dbi:mysql:database=trappola;host=services';
    my $username = 'root';
    my $password = undef;
    my %attr = (
        AutoCommit => 0,
        RaiseError => 1
    );
$username = 'trappola';
$password = 'trappass';
#    $self->{'db'}->{AutoCommit} = 0;
#    $self->{'db'}->{RaiseError} = 1;

    $self->{'dbh'} = DBI->connect($dsn, $username, $password, \%attr);
}

sub DESTROY {

}

1;
