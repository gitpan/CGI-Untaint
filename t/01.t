#!/usr/bin/perl -w

use Test::More tests => 5;

use strict;
use CGI;
use CGI::Untaint;

my $i_name = "Tony Bowden";
my $i_age  = 110;
my $i_neg  = -10;

my $q = CGI->new({
  name => $i_name, 
  age  => $i_age,
  neg  => $i_neg,
});

ok(my $data = CGI::Untaint->new( $q->Vars ), "Can create the handler");

my $name   = $data->extract(-as_printable => 'name');
my $age    = $data->extract(-as_integer   => 'age');
my $neg    = $data->extract(-as_integer   => 'neg');

is($name,  $i_name, "Name");
is($age,   $i_age,  "Age");
is($neg,   $i_neg,  "Negative integer");

my $foo = $data->extract(-as_printable => 'foo');
ok(!$foo, "No Foo");

