#!/usr/bin/perl -w

use Test::More tests => 5;

use strict;
use CGI;
use CGI::Untaint;

my $q = CGI->new({ 
  ok  => (join '', map chr($_), (32..255)),
  not => (join '', map chr($_), (0 .. 31)),
  mix => ("Hello ".chr(17).chr(0)."World"),
  win => "Hello World\r\nPart 2",
});

ok(my $data = CGI::Untaint->new( $q->Vars ), "Can create the handler");

is($data->extract(-as_printable => 'ok'),  $q->param('ok'),  'Printable');
is($data->extract(-as_printable => 'win'), $q->param('win'), 'Printable');
ok(!$data->extract(-as_printable => 'not'), 'Not printable');
ok(!$data->extract(-as_printable => 'mix'), 'Mixed');
