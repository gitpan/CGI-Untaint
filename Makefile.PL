use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'CGI::Untaint',
    'VERSION_FROM'	=> 'lib/CGI/Untaint.pm', # finds $VERSION
    'PREREQ_PM'		=> { 
                              Test::More => 0.11,
                              UNIVERSAL::require => 0.01,
                           }, 
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'lib/CGI/Untaint.pm', # retrieve abstract from module
       AUTHOR        => 'Tony Bowden <tony@tmtm.com>') : ()),
);
