#!/usr/bin/perl

use strict;
use warnings;
use English qw( -no_match_vars );

# version info
use version; our $VERSION = qv('0.1_1');

my $description = <<'ENDDESC';
================================================================================
 Installer Script for WebifyIMG.pm
================================================================================

 This script checks if your system is ready to use webify-cli.pl, and if it is,
 Installs the relevant files to the default locations.

Returns Codes:
==============
 0 - success
 1 - error
 
ENDDESC

#
# Defing needed Constants
#

# install base directory
my $INSTALL_BASE = '/usr/local/WebifyIMG/';

# Required Perl modules
my @PERL_MODS = qw{Carp Config::Simple IO::CaptureOutput String::ShellQuote Getopt::Long Data::Dumper lib::findbin};

# binary paths
my $CP     = '/bin/cp';
my $CPAN   = '/usr/bin/cpan';
my $MKDIR  = '/bin/mkdir';
my $UNAME  = '/usr/bin/uname';
my $WHICH  = '/usr/bin/which';
my $WHOAMI = '/usr/bin/whoami';

#
# Pre-flight checks
#

print <<'END_TEXT';

*** PRE-FLIGHT CHECKS ***

** ENVIRONMENT **

END_TEXT

print 'Ensure this is OS X ... ';
my $running_on = `$UNAME`;
chomp $running_on;
unless($running_on eq 'Darwin'){
    print "NO\n\nSorry - this installer has only been tested on OS X\n\n";
    exit 1;
}
print "OK\n";
print 'Ensure we are running as root ... ';
my $running_as = `$WHOAMI`;
chomp $running_as;
unless($running_as eq 'root'){
    print "NO\n\nERROR - this installer must be run as root:\n\tsudo ./installer.pl\n\n";
    exit 1;
}
print "OK\n";

print <<'END_TEXT';

** PERL MODULES **

Checking if the needed Perl modules are installed:
END_TEXT

foreach my $mod (@PERL_MODS){
    print "Checking $mod ... ";
    eval "require $mod;"
    or do{
        print "NOT FOUND\n\nYou need to install the Perl module $mod before continuing:\n";
        print "\tsudo /usr/bin/cpan -i '$mod'\n\n";
        exit 1;
    };
    print "OK\n";
}

print <<'END_TEXT';

** IMAGE MAGICK BINARIES **

Checking if the ImageMagick Binaries are installed:

END_TEXT

my $mogrigy_path = `$WHICH mogrify`;
chomp $mogrigy_path;
unless($mogrigy_path){
    print "ERROR - could not find Image Magick binaries\n\n";
    exit 1;
}
my $image_magick_path = $mogrigy_path;
$image_magick_path =~ s/mogrify$//sx;
print "OK - path=$image_magick_path\n";

print <<'END_TEXT';

** CHECK FOR EXISTING INSTALL **

END_TEXT

if(-e $INSTALL_BASE){
    print "ERROR - pre-existing install at $INSTALL_BASE\n\n";
}
print "OK - nothing at $INSTALL_BASE\n";

print <<'END_TEXT';

--- ALL OK ---

*** INSTALLING WebifyIMG LIBRARY ***

END_TEXT
print "Creating $INSTALL_BASE ... ";
if(system("$MKDIR $INSTALL_BASE") != 0){
    print "FAILED\n\nERROR - failed to create $INSTALL_BASE\n\n";
    exit 0;
}
print "OK\n";
print "Creating ${INSTALL_BASE}lib/ ... ";
if(system("$MKDIR ${INSTALL_BASE}lib") != 0){
    print "FAILED\n\nERROR - failed to create ${INSTALL_BASE}lib/\n\n";
    exit 0;
}
print "OK\n";
print "Creating ${INSTALL_BASE}lib/WebifyIMG ... ";
if(system("$MKDIR ${INSTALL_BASE}lib/WebifyIMG") != 0){
    print "FAILED\n\nERROR - failed to create ${INSTALL_BASE}lib/WebifyIMG\n\n";
    exit 0;
}
print "OK\n";
print 'Copying WebifyIMG.pm into place ... ';
if(system("$CP lib/WebifyIMG.pm  ${INSTALL_BASE}lib/") != 0){
    print "FAILED\n\nERROR - failed to copy WebifyIMG.pm into place\n\n";
    exit 0;
}
print "OK\n";
print 'Copying ImageSet.pm into place ... ';
if(system("$CP lib/WebifyIMG/ImageSet.pm  ${INSTALL_BASE}lib/WebifyIMG/") != 0){
    print "FAILED\n\nERROR - failed to copy ImageSet.pm into place\n\n";
    exit 0;
}
print "OK\n";
print 'Copying webify-cli.pl into place ... ';
if(system("$CP webify-cli.pl  ${INSTALL_BASE}") != 0){
    print "FAILED\n\nERROR - failed to copy webify-cli.pl into place\n\n";
    exit 0;
}
print "OK\n";
