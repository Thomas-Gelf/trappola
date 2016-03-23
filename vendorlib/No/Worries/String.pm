#+##############################################################################
#                                                                              #
# File: No/Worries/String.pm                                                   #
#                                                                              #
# Description: string handling without worries                                 #
#                                                                              #
#-##############################################################################

#
# module definition
#

package No::Worries::String;
use strict;
use warnings;
our $VERSION  = "1.0";
our $REVISION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

#
# used modules
#

use No::Worries::Export qw(export_control);
use Params::Validate qw(validate validate_pos :types);

#
# global variables
#

our(
    @_Map,   # mapping of characters to escaped strings
);

#
# escape a string (quite compact, human friendly but not Perl eval()'able)
#

sub string_escape ($) {
    my($string) = @_;
    my(@list);

    validate_pos(@_, { type => SCALAR });
    foreach my $ord (map(ord($_), split(//, $string))) {
        push(@list, $ord < 256 ? $_Map[$ord] : sprintf("\\x{%04x}", $ord));
    }
    return(join("", @list));
}

#
# transform a table into a string
#

my %string_table_options = (
    colsep  => { optional => 1, type => SCALAR },
    header  => { optional => 1, type => ARRAYREF },
    headsep => { optional => 1, type => SCALAR },
    indent  => { optional => 1, type => SCALAR },
);

sub string_table ($@) {
    my($lines, %option, @length, $index, $length, $format, $result);

    # handle options
    $lines = shift(@_);
    %option = validate(@_, \%string_table_options) if @_;
    $option{colsep} = " | " unless defined($option{colsep});
    $option{headsep} = "=" unless defined($option{headsep});
    $option{indent} = "" unless defined($option{indent});
    # compute column lengths
    foreach my $line ($option{header} ? ($option{header}) : (), @{ $lines }) {
        $index = 0;
        foreach my $entry (@{ $line }) {
            $length = defined($entry) ? length($entry) : 0;
            $length[$index] = $length
                unless defined($length[$index]) and $length[$index] >= $length;
            $index++;
        }
    }
    # setup formatting
    $length = length($option{colsep}) * (@length - 1);
    foreach my $colen (@length) {
        $length += $colen;
    }
    $format = join($option{colsep}, map("%-${_}s", @length)) . "\n";
    $result = "";
    # format header
    if ($option{header}) {
        $result .= $option{indent};
        $result .= sprintf($format, @{ $option{header} });
        $result .= $option{indent};
        $result .= substr($option{headsep} x $length, 0, $length) . "\n";
    }
    # format lines
    foreach my $line (@{ $lines }) {
        $result .= $option{indent};
        $result .= sprintf($format, map(defined($_) ? $_ : "",
                                        map($line->[$_], 0 .. $#length)));
    }
    return($result);
}

#
# remove leading and trailing spaces
#

sub string_trim ($) {
    my($string) = @_;

    validate_pos(@_, { type => SCALAR });
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return($string);
}

#
# module initialization
#

foreach my $ord (0 .. 255) {
    $_Map[$ord] = 32 <= $ord && $ord < 127 ?
        chr($ord) : sprintf("\\x%02x", $ord);
}
$_Map[ord("\t")] = "\\t";
$_Map[ord("\n")] = "\\n";
$_Map[ord("\r")] = "\\r";
$_Map[ord("\e")] = "\\e";
$_Map[ord("\\")] = "\\\\";

#
# export control
#

sub import : method {
    my($pkg, %exported);

    $pkg = shift(@_);
    grep($exported{$_}++, map("string_$_", qw(escape table trim)));
    export_control(scalar(caller()), $pkg, \%exported, @_);
}

1;

__DATA__

=head1 NAME

No::Worries::String - string handling without worries

=head1 SYNOPSIS

  use No::Worries::String qw(string_escape string_table string_trim);

  # escape a string
  printf("found %s\n", string_escape($data));

  # format a table
  print(string_table([
      [1, 1,  1],
      [2, 4,  8],
      [3, 9, 27],
  ], header => [qw(x x^2 x^3)]));

  # trim a string
  $string = string_trim($input);

=head1 DESCRIPTION

This module eases string handling by providing convenient string
manipulation functions.

=head1 FUNCTIONS

This module provides the following functions (none of them being
exported by default):

=over

=item string_escape(STRING)

return a new string with all potentially non-printable characters
escaped; this includes ASCII control characters, non-7bit ASCII and
Unicode characters

=item string_table(TABLE[, OPTIONS])

transform the given table (a reference to an array of arrays of strings)
into a formatted multi-line string; supported options:

=over

=item * C<colsep>: column separator string (default: " | ")

=item * C<header>: array reference of column headers (default: none)

=item * C<headsep>: header separator (default: "=")

=item * C<indent>: string to prepend to each line (default: "")

=back

=item string_trim(STRING)

return a new string with leading and trailing spaces removed

=back

=head1 SEE ALSO

L<No::Worries>.

=head1 AUTHOR

Lionel Cons L<http://cern.ch/lionel.cons>

Copyright (C) CERN 2012-2013
