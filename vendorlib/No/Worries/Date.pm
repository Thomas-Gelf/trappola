#+##############################################################################
#                                                                              #
# File: No/Worries/Date.pm                                                     #
#                                                                              #
# Description: date handling without worries                                   #
#                                                                              #
#-##############################################################################

#
# module definition
#

package No::Worries::Date;
use strict;
use warnings;
use 5.005; # need the four-argument form of substr()
our $VERSION  = "1.0";
our $REVISION = sprintf("%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/);

#
# used modules
#

use HTTP::Date qw(str2time);
use No::Worries::Die qw(dief);
use No::Worries::Export qw(export_control);
use Params::Validate qw(validate_pos :types);
use POSIX qw(strftime);

#
# constants
#

use constant STRFTIME_STRING_FORMAT => "%Y-%m-%dT%H:%M:%SZ";
use constant STRFTIME_STAMP_FORMAT  => "%Y/%m/%d-%H:%M:%S";

#
# convert a string to a time
#

sub date_parse ($) {
    my($string) = @_;
    my($time);

    validate_pos(@_, { type => SCALAR });
    $time = str2time($string);
    dief("invalid date: %s", $string) unless defined($time);
    return($time);
}

#
# convert a time to human friendly string (local time)
#

sub date_stamp (;$) {
    my($time) = @_;
    my($string);

    validate_pos(@_, { type => SCALAR }) if @_;
    $time = time() unless defined($time);
    if ($time =~ /^(\d+)$/) {
        $string = strftime(STRFTIME_STAMP_FORMAT, localtime($1));
    } elsif ($time =~ /^(\d+)\.(\d+)$/) {
        $string = strftime(STRFTIME_STAMP_FORMAT, localtime($1));
        $string .= ".$2";
    } else {
        dief("invalid time: %s", $time);
    }
    return($string);
}

#
# convert a time to an ISO 8601 compliant string (UTC based)
#

sub date_string (;$) {
    my($time) = @_;
    my($string);

    validate_pos(@_, { type => SCALAR }) if @_;
    $time = time() unless defined($time);
    if ($time =~ /^(\d+)$/) {
        $string = strftime(STRFTIME_STRING_FORMAT, gmtime($1));
    } elsif ($time =~ /^(\d+)\.(\d+)$/) {
        $string = strftime(STRFTIME_STRING_FORMAT, gmtime($1));
        substr($string, -1, 0, ".$2");
    } else {
        dief("invalid time: %s", $time);
    }
    return($string);
}

#
# export control
#

sub import : method {
    my($pkg, %exported);

    $pkg = shift(@_);
    grep($exported{$_}++, map("date_$_", qw(parse stamp string)));
    export_control(scalar(caller()), $pkg, \%exported, @_);
}

1;

__DATA__

=head1 NAME

No::Worries::Date - date handling without worries

=head1 SYNOPSIS

  use No::Worries::Date qw(date_parse date_stamp date_string);

  $string = date_stamp();
  # e.g. 2012/04/12-11:01:42

  $string = date_string(time());
  # e.g. 2012-04-12T09:01:42Z

  $string = date_string(Time::HiRes::time());
  # e.g. 2012-04-12T09:01:42.48602Z

  $time = date_parse("Sun, 06 Nov 1994 08:49:37 GMT");

=head1 DESCRIPTION

This module eases date handling by providing convenient wrappers
around standard date functions. All the functions die() on error.

The strings and times may include fractional seconds like in the
example above.

date_parse() can accept many more formats than simply what
date_stamp() and date_string() return.

=head1 FUNCTIONS

This module provides the following functions (none of them being
exported by default):

=over

=item date_parse(STRING)

parse the given string and return the corresponding numerical time
(i.e. the number of non-leap seconds since the epoch) or an error;
L<HTTP::Date>'s str2time() is used for the parsing

=item date_stamp([TIME])

convert the given numerical time (or the current time if not given) to
a human friendly, compact, local time string

=item date_string([TIME])

convert the given numerical time (or the current time if not given) to
a standard, ISO 8601 compliant, UTC based string

=back

=head1 SEE ALSO

L<HTTP::Date>,
L<No::Worries>.

=head1 AUTHOR

Lionel Cons L<http://cern.ch/lionel.cons>

Copyright (C) CERN 2012-2013
