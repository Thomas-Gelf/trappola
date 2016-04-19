package Trappola::TrapDb;

use strict;
use warnings;

use DBI;
use Module::Load;

# use Socket qw(:DEFAULT);
# use Data::Dumper;

sub new {
    my $class = shift;
    my $config = shift;
    my $self = {
        'config' => $config
    };

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

sub fetchCol {
    my $self = shift;
    my $sql = shift;
    my $sth = $self->execute($sql, @_);
    return $self->db->selectcol_arrayref($sql);
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

    my $host     = $self->config('db', 'host', 'localhost');
    my $username = $self->config('db', 'username', 'root');
    my $password = $self->config('db', 'password', undef);
    my $database = $self->config('db', 'dbname', 'trappola');

    my $dsn = sprintf(
        'dbi:mysql:database=%s;host=%s',
        $database,
        $host
    );

    my %attr = (
        AutoCommit => 0,
        RaiseError => 1
    );

    $self->{'dbh'} = DBI->connect($dsn, $username, $password, \%attr);
}

sub config {
    return shift->{'config'}->get(@_);
}

sub DESTROY {
    my $self = shift;
    $self->db->disconnect if $self->db;
}

1;
