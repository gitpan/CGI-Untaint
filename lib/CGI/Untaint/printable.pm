package CGI::Untaint::printable;

use strict;
use base 'CGI::Untaint::object';

sub _untaint_re { 
  qr/^([\040-\377\r\n]+)$/ 
}

=head1 NAME

CGI::Untaint::printable - validate as a printable value

=head1 SYNOPSIS

  my $name = $handler->extract(-as_printable => 'name');

=head1 DESCRIPTION

This Input Handler verifies that it is dealing with an 'printable'
string (i.e. characters in the range \040-\377 (plus \r and \n).

This is occasionally a useful 'fallback' pattern, but in general you
will want to write your own patterns to be stricter.

=head1 AUTHOR

Tony Bowden, E<lt>kasei@tmtm.comE<gt>.

=head1 COPYRIGHT

Copyright (C) 2001 Tony Bowden. All rights reserved.

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
