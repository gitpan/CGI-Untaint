package CGI::Untaint;

use vars qw/$VERSION/;
$VERSION = '1.00';

=head1 NAME 

CGI::Untaint - process CGI input parameters

=head1 SYNOPSIS

  use CGI::Untaint;

  my $q = new CGI;
  my $handler = CGI::Untaint->new( $q->Vars );
  my $handler2 = CGI::Untaint->new({
		INCLUDE_PATH => 'MyRecipes',
	}, $apr->parms);

  my $name     = $handler->extract(-as_printable => 'name');
  my $homepage = $handler->extract(-as_url => 'homepage');

  my $postcode = $handler->extract(-as_postcode => 'address6');

  # Create your own handler...

  package MyRecipes::CGI::Untaint::legal_age;
  use base 'CGI::Untaint::integer';
  sub is_valid { 
    shift->value > 21;
  }

  package main;
  my $age = $handler->extract(-as_legal_age => 'age');

=head1 DESCRIPTION

Dealing with large web based applications with multiple forms is a
minefield. It's often hard enough to ensure you validate all your
input at all, without having to worry about doing it in a consistent
manner. If any of the validation rules change, you often have to alter
them in many different places. And, if you want to operate taint-safe,
then you're just adding even more headaches.

This module provides a simple, convenient, abstracted and extensible
manner for validating and untainting the input from web forms.

You simply create a handler with a hash of your parameters (usually
$q->Vars), and then iterate over the fields you wish to extract,
performing whatever validations you choose. The resulting variable is
guaranteed not only to be valid, but also untainted.

=cut

use strict;
use Carp;
use UNIVERSAL::require;

=head2 new

  my $handler  = CGI::Untaint->new( $q->Vars );
  my $handler2 = CGI::Untaint->new({
		INCLUDE_PATH => 'MyRecipes',
	}, $apr->parms);

The simplest way to contruct an input handler is to pass a hash of
parameters (usually $q->Vars) to new(). Each parameter will then be able
to be extracted later by calling an extract() method on it.

However, you may also pass a leading reference to a hash of configuration
variables.

Currently the only such variable supported is 'INCLUDE_PATH', which
allows you to specify a local path in which to find extraction handlers.
See L<LOCAL EXTRACTION HANDLERS>.

=cut

sub new {
  my $class = shift;

  # want to cope with any of:
  #  (%vals), (\%vals), (\%config, %vals) or (\%config, \%vals)
  #    but %vals could also be an object ...
  my ($vals, $config);

	if (@_ == 1) {
		# only one argument - must be either hashref or obj.
		$vals = ref $_[0] eq "HASH" ? shift : { %{+shift} }

	} elsif (@_ > 2) {
		# Conf + Hash or Hash
		$config = shift if ref $_[0] eq "HASH";
		$vals={ @_ }

	} else {
		# Conf + Hashref or 1 key hash
		ref $_[0] eq "HASH" ? ($config, $vals) = @_ : $vals = {@_};
	}
		
  $vals->{__config} = $config;
  bless $vals, $class;
}

sub error { $_[0]->{_ERR} }

=head2 extract

  my $homepage = $handler->extract(-as_url => 'homepage');
  my $state = $handler->extract(-as_us_state => 'address4');
  my $state = $handler->extract(-as_like_us_state => 'address4');

Once you have constructed your Input Handler, you call the 'extract'
method on each piece of data with which you are concerned.

The takes an -as_whatever flag to state what type of data you
require. This will check that the input value correctly matches the
required specification, and return an untainted value. It will then call
the is_valid() method, where applicable, to ensure that this doesn't
just _look_ like a valid value, but actually is one.

If you want to skip this stage, then you can call -as_like_whatever
which will perform the untainting but not the validation.

=cut

sub extract {
  my $self = shift;
  
  my %param = @_;

  #----------------------------------------------------------------------
  # Make sure we have a valid data handler
  #----------------------------------------------------------------------
  my @as = grep /^-as_/, keys %param;
  croak "No data handler type specified" unless @as;
  croak "Multiple data handler types specified" unless @as == 1;

  my $field = delete $param{$as[0]};
  my $skip_valid = $as[0] =~ s/^(-as_)like_/$1/;
  my $module = $self->_load_module($as[0]);
  $self->{_ERR} = "";

  unless (defined $field) {
    $self->{_ERR} = "Required value '$field' does not exist";
    return;
  } 

  #----------------------------------------------------------------------
  # Do we have a sensible value? Check the default untaint for this
  # type of variable, unless one is passed.
  #----------------------------------------------------------------------
  $self->{value} = $self->{$field};
  unless (defined $self->{value}) {
    $self->{_ERR} = "No parameter for '$field'";
    return;
  } 

  # 'False' values get returned as themselves with no warnings.
  return $self->{value} unless $self->{value};

  my $handler = $module->_new($self);
  if (my $untaint_re = delete $param{'-taint_re'}) {
    unless ($self->{value} =~ $untaint_re) {
      $self->{_ERR} = 
       "$field ($self->{value}) does not untaint with specified pattern";
      return;
    }
  } else {
    unless ($handler->_untaint) {
      $self->{_ERR} = 
       "$field ($self->{value}) does not untaint with default pattern";
      return;
    }
  }

  #----------------------------------------------------------------------
  # Are we doing a validation check?
  #----------------------------------------------------------------------
  unless ($skip_valid) {
    if (my $ref = $handler->can('is_valid')) {
      unless ($handler->$ref()) {
        $self->{_ERR} =
         "$field ($self->{value}) does not pass the is_valid() check";
        return;
      }
    }
  }

  #----------------------------------------------------------------------
  # Check any others. This is from an old version, and is deprecated
  # in favour of is_valid().
  # This may go away, or change dramatically in later versions.
  #----------------------------------------------------------------------
  foreach my $key (map { substr $_, 1} keys %param) {
    my $value = $param{"-$key"};
    unless ($handler->can($key)) {
      $self->{_ERR} = "Handler for $field cannot test $key";
      return;
    }
    unless ($handler->$key($value)) {
      $self->{_ERR} ||= "Handler for $field failed test for $key";
      return;
    }
  }
  return $self->{value};
}

sub _load_module {
  my $self = shift;
  my $name = $self->_get_module_name(shift());
  return $self->{__loaded}{$name} if defined $self->{__loaded}{$name};

  eval { $name->require or die };
  return $self->{__loaded}{$name} = $name unless $@;

  # Do we have an alternate path?
  my $path = $self->{__config}{INCLUDE_PATH} or die $@;
     $path =~ s/\//::/g;
     $path =~ s/^:://;
  my $new_name = "$path\::$name";
  $new_name->require;
  return $self->{__loaded}{$name} = $new_name;
}

# Convert the -as_whatever to a FQ module name
sub _get_module_name {
  my $self = shift;
  (my $handler = shift) =~ s/^-as_//;
  return join "::", ref($self), $handler;
}

=head1 LOCAL EXTRACTION HANDLERS

As well as as the handlers supplied with this module for extracting
data, you may also create your own. In general these should inherit from
'CGI::Untaint::object', and must provide an '_untaint_re' method which
returns a compiled regular expression, suitably bracketed such that $1
will return the untainted value required.

e.g. if you often extract single digit variables, you could create 

  package Mysite::CGI::Untaint::digit;
  use base 'CGI::Untaint::object';
  sub _untaint_re { qr/^(\d)$/ }
  1;

You should specify the path to 'Mysite' in the INCLUDE_PATH configuration
option.  (See new() above.)

When extract() is called CGI::Untaint will automatically check to see if
you have an is_valid() method also, and if so will run this against the
value extracted from the regular expression (available as $self->value).
If this returns a true value, then the extracted value will be returned,
otherwise we return undef. (is_valid() can also modify the value being
returned, by assigning to $self->value)

e.g. in the above example, if you sometimes need to ensure that the
digit extracted is prime, you would supply:

  sub is_valid { (1 x shift->value) !~ /^1?$|^(11+?)\1+$/ };

Now, when users call extract(), it will also check that the value
is valid(), i.e. prime:

  my $number = $handler->extract(-as_digit => 'value');

A user wishing to skip the validation, but still ensure untainting can
call 

  my $number = $handler->extract(-as_like_digit => 'value');

=head2 Test::CGI::Untaint

If you create your own local handlers, then you may wish to explore
L<Test::CGI::Untaint>, available from the CPAN. This makes it very easy
to write tests for your handler. (Thanks to Profero Ltd.)

=head1 AVAILABLE HANDLERS

This package comes with the following simplistic handlers: 

  printable  - a printable string
  integer    - an integer
  hex        - a hexadecimal number (as a string)

To really make this work for you you either need to write, or download
from CPAN, other handlers. Currently available handlers from CPAN include:

  CGI::Untaint::creditcard
  CGI::Untaint::date
  CGI::Untaint::email
  CGI::Untaint::isbn
  CGI::Untaint::uk_postcode
  CGI::Untaint::url

If you create any others, please let me know and I'll include them here.
(Or, if you have requests for other handlers, let me know and I'll see
if I can create them).

=head1 BUGS

None known yet.

=head1 SEE ALSO

L<CGI>. L<perlsec>. L<Test::CGI::Untaint>.

=head1 AUTHOR

Tony Bowden, E<lt>kasei@tmtm.comE<gt>.

=head1 FEEDBACK

I'd love to hear from you if you start using this. I'd particularly like
to hear any suggestions as to how to make it even better / easier etc.

=head1 COPYRIGHT

Copyright (C) 2001-2003 Tony Bowden. All rights reserved.

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
