#!/usr/bin/perl -w

use strict;
use File::Basename;
use File::Path;
use CGI;
use CGI::Untaint;
use vars qw/$TESTS/;
BEGIN { $TESTS = 12 };
use Test::More tests => $TESTS;

eval {
  require File::Temp;
};
SKIP: {
  skip "Need File::Temp", $TESTS if $@;
  File::Temp->import(qw/tempfile tempdir/);

  my $dir = tempdir( CLEANUP => 1 );
  push @INC, $dir;
  my $loc = "$dir/CGI/Untaint";
  mkpath($loc) or die "Can't create path: $!\n";
  ok(-d $loc, "We have a path for our file");
  
  my ($fh, $filename) = tempfile( "TestXXXX", DIR => $loc, SUFFIX => '.pm');

  my $package = substr(basename($filename), 0, -3);
  is ("$loc/$package.pm", $filename, "Package $loc/$package.pm OK"); 

  my $string = "package CGI::Untaint::$package;\n";
     $string .= <<'';
use base 'CGI::Untaint::object';
sub _untaint_re { qr/^(\d)$/ }
sub is_valid { (1 x shift->value) !~ /^1?$|^(11+?)\1+$/ };
1;

  print $fh $string;
  close $fh;

  my $q = CGI->new({ 
    ok       => 6, 
    not      => 10,
    prime    => 7,
    notprime => 8,
  });

  ok(my $data = CGI::Untaint->new({ INCLUDE_PATH => $dir }, $q->Vars ), 
    "Can create the handler, with INCLUDE_PATH");
  
  is($data->{__config}{INCLUDE_PATH}, $dir, "INCLUDE_PATH set");

  is($data->extract("-as_like_$package" => 'ok'),  6, '6 passes');
  is($data->error, undef, "And we have no errors");
  ok(!$data->extract("-as_like_$package" => 'not'), '10 fails');
  is($data->error, "not (10) does not untaint with default pattern", 
     " - with suitable error");

  is($data->extract("-as_$package" => 'prime'), 7, '7 passes prime test');
  is($data->error, undef, "And we have no errors");

  ok(!$data->extract("-as_$package" => 'notprime'), '8 fails prime test');
  is($data->error, 'notprime (8) does not pass the is_valid() check',
   " - with suitable error");

}
