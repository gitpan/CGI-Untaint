package CGI::Untaint::object;

=head1 NAME

CGI::Untaint::object - base class for Input Handlers

=head1 SYNOPSIS

  package MyUntaint::foo;

  use base 'CGI::Untaint::object';

  sub _untaint_re {
    return qr/$your_regex/;
  }

  sub is_valid {
    my $self = shift;
    my $value = $self->value;
    return is_ok($self->value);
  }

  1;

  # then...

  my $handler = CGI::Untaint->new({
    INCLUDE_PATH = 'MyUntaint',
  }, $q->Vars );

  my $bar = $handler->extract(-as_foo => 'field10');

=head1 DESCRIPTION

This is the base class that all Untaint objects should inherit
from. 

=head1 AUTHOR

Tony Bowden, E<lt>kasei@tmtm.comE<gt>.

=head1 COPYRIGHT

Copyright (C) 2001 Tony Bowden. All rights reserved.

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;

sub _new  { bless { _obj => $_[1]}, $_[0] }

sub value { 
  my $self = shift;
  $self->{_obj}->{value} = shift if @_;
  $self->{_obj}->{value};
}

sub _untaint {
  my $self = shift;
  my $re = $self->_untaint_re;
  unless ($self->value and $self->value =~ $self->_untaint_re) {
    $self->{_ERR} = "Untaint failed";
    return;
  }
  $self->value($1);
  return 1;
}

sub is_valid { 1 }

# Return the entire thing, untainted. This should only be used if
# you have already validated your entry in some way that means you
# completely trust the data.
sub re_all  { qr/(.*)/ }
sub re_none { qr/(?!)/ }

1;
