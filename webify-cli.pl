#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long; # for argument processing
use lib::findbin; # from CPAN
use WebifyIMG;

# version info
use version; our $VERSION = qv('0.1_1');

my $description = <<'ENDDESC';
#==============================================================================#
# CLI wrapper for WebifyIMG.pm                                                 #
#==============================================================================#
#                                                                              #
# This script provides a wrapper for the WebifyIMG.pm Perl module.             #
# This script alters the images it is called on, so it should only be used on  #
# images exported from a photomanagement app (e.g. Aperture or Lighroom)       #
# specifically for uploading to the web, or on duplucates of your original     #
# images. It should NEVER be used on your original image files, EVER!          #
#                                                                              #
# Synopsis:                                                                    #
# =========                                                                    #
# Print Version Number:         webify-cli.pl --version                        #
#                                                                              #
# Print List of Operations:     webify-cli.pl --list                           #
#                                                                              #
# Process one or more Images:   webify-cli.pl [operation] [files] [flags]      #
#                                                                              #
# Global Optional Flags:                                                       #
# ======================                                                       #
# -d, --debug      Enter Debug mode - no changes will be made to any image     #
#                  files. (Implies --verbose)                                  #
# -v, --verbose    Verbose output.                                             #
#                                                                              #
# Returns Codes:                                                               #
# ==============                                                               #
# 0 - success                                                                  #
# 1 - error                                                                    #
#                                                                              #
#==============================================================================#
ENDDESC

#
# Process and Validate Arguments
#
my %options; # hash to store commandline flags
unless(GetOptions(\%options,
        'verbose|v',
        'version',
        'debug|d',
)){
    print "\nERROR - invalid arguments\n\n$description\n";
    exit 1;
}
my $debug = 0;
if($options{debug}){
    $debug = 1;
    print "DEBUG - entering debug mode\n";
}
my $verbose = 0;
if($debug || $options{verbose}){
    $verbose = 1;
    print "INFO - verbose output enabled\n";
}

#
# Deal with special modes of operation
#

# --version
if($options{version}){
    print "webify-cli.pl    - $VERSION\n";
    print "WebifyIMG.pm     - $WebifyIMG::VERSION\n";
    exit 0;
}

#
# Utility Functions
#
