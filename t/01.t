#!/usr/bin/perl -w

use Test::More tests => 19;

use strict;
use CGI;
use CGI::Untaint;

my $data = {
  name => "Tony Bowden",
  age  => 110,
  neg  => -10,
  hex  => "a15b",
};

my %type = (
  name => 'printable',
  age  => 'integer',
  neg  => 'integer',
  hex  => 'hex',
);


{
  my $q = CGI->new($data);
  ok my $h = CGI::Untaint->new( $q->Vars ), "Create the handler";
  isa_ok $h, "CGI::Untaint";
  foreach (keys %type) {
    ok my $res = $h->extract("-as_$type{$_}" => $_), "Extract $_";
    is $res,  $data->{$_}, " - Correct value";
    is $h->error, '', "No error";
  }
  my $foo = $h->extract(-as_printable => 'foo');
  ok !$foo, "No Foo";
  is $h->error, "No parameter for 'foo'", "No error";
}

{
  local $data->{hex} = "a15g";
  my $q = CGI->new($data);
  ok my $h = CGI::Untaint->new( $q->Vars ), "Create the handler";
  my $hex = $h->extract(-as_hex => 'hex');
  ok !$hex, "Invalid hex";
  like $h->error, qr/does not untaint with default pattern/, $h->error;
}

