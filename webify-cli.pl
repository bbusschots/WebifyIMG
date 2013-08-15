#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long; # for argument processing
use Data::Dumper; # for debugging
use IO::Prompt; # from CPAN - for user input
use lib::findbin; # from CPAN - to allow the script be run from any location
use WebifyIMG;
use WebifyIMG::ImageSet;

# version info
use version; our $VERSION = qv('0.1_4');

my $description = <<'ENDDESC_SHORT';
================================================================================
 CLI wrapper for WebifyIMG.pm
================================================================================

 This script provides a wrapper for the WebifyIMG.pm Perl module.
 This script alters the images it is called on, so it should only be used on
 images exported from a photomanagement app (e.g. Aperture or Lighroom)
 specifically for uploading to the web, or on duplucates of your original
 images. It should NEVER be used on your original image files, EVER!

Synopsis:
=========
 Print List of Operations:     webify-cli.pl --list

 Print documentation:          webify-cli.pl -h|--help

 Print Version Number:         webify-cli.pl --version

 Process one or more Images:   webify-cli.pl 'operation' [files] [flags]

ENDDESC_SHORT
my $description_extra = <<'ENDDESC_EXTRA';
Global Optional Flags:
======================
 -d, --debug        Enter Debug mode - no changes will be made to any image
                    files. (Implies --verbose)
 -v, --verbose      Verbose output.
 -y, --yes          Skip the warning message before altering an image.
 -q, --quiet        Supress progress messages from the WebifyIMG library.

Other Flags:
============
 Some operations support additions flags (to see what operation supports
 what flags use --list). The following flags are possible:
 -b, --border       The width of a border in pixels (must be integer)
 -c, --colour       Specify a colour in some format accepted by ImageMagick.
     --color        Alias for --colour for Americas :)

Returns Codes:
==============
 0 - success
 1 - error
 
ENDDESC_EXTRA
my $description_extended = $description.$description_extra;

#
# Assemble the list of valid operations
#
my $OPERATIONS = {
    'frame' => {
        min_images => 1,
        options => {
            colour => '#999999',
            border => 1,
        },
        description => 'Adds a basic border to the specified images - defaults to 1px #999999',
        function => \&_frame,
    },
};

#
# Process and Validate Arguments
#
my %options; # hash to store commandline flags
unless(GetOptions(\%options,
        'border|b=i',
        'colour|color|c=s',
        'debug|d',
        'help|h',
        'list|l',
        'quiet|q',
        'verbose|v',
        'version',
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

# --help
if($options{help}){
    print "\n".$description_extended;
    exit 0;
}

# --list
if($options{list}){
    # loop through the list of operations and print each
    print "\nSupported Operations:\n=====================\n";
    foreach my $operation (sort keys %{$OPERATIONS}){
        print "* $operation:\n";
        print "- Description: $OPERATIONS->{$operation}->{description}\n";
        if($OPERATIONS->{$operation}->{min_images} && $OPERATIONS->{$operation}->{max_images} && $OPERATIONS->{$operation}->{min_images} == $OPERATIONS->{$operation}->{max_images}){
            print "- Images Required: exactly $OPERATIONS->{$operation}->{min_images}\n";
        }else{
            if($OPERATIONS->{$operation}->{min_images}){
                print "- Minimum Images Required: $OPERATIONS->{$operation}->{min_images}\n";
            }
            if($OPERATIONS->{$operation}->{max_images}){
                print "- Maximum Images Accepted: $OPERATIONS->{$operation}->{max_images}\n";
            }
        }
        if(scalar keys %{$OPERATIONS->{$operation}->{options}}){
            my @text_options = ();
            foreach my $option (sort  keys %{$OPERATIONS->{$operation}->{options}}){
                push @text_options, "--$option (default='$OPERATIONS->{$operation}->{options}->{$option}')";
            }
            print '- Options Supported: ';
            print join q{, }, @text_options;
            print "\n";
        }
    }
    print "\n";
    exit 0;
}

# --version
if($options{version}){
    print "webify-cli.pl:   $VERSION\n";
    print "WebifyIMG.pm:    $WebifyIMG::VERSION\n";
    exit 0;
}

#
# Process a reguar request
#

# ensure that a valid operation was specified
my $operation_name = shift @ARGV;
unless($operation_name){
    print "\nERROR - invalid arguments - no operation specified\n\n$description";
    exit 1;
}
unless($OPERATIONS->{$operation_name}){
    print "\nERROR - inavlid operation '$operation_name' (use --list to list available operations)\n\n";
    exit 1;
}
my $operation = $OPERATIONS->{$operation_name};
$operation->{name} = $operation_name;

# get list of images
my @images = ();
while(@ARGV){
    push @images, shift @ARGV;
}
my $num_images = scalar @images;

# ensure all the images exist
if($num_images){
    print 'INFO - ensuring all supplied image paths are valid ... ' if $verbose;
    foreach my $image (@images){
        unless(-f $image){
            print "FAIL\n" if $verbose;
            print "\nERROR - file $image does not exist\n\n";
            exit 1;
        }
    }
    print "OK\n" if $verbose;
}

# ensure we got the required number of images
print 'INFO - validating number of supplied images ... ' if $verbose;
if($operation->{min_images} && $operation->{max_images}){
    # both min and max specified
    unless($num_images >= $operation->{min_images} && $num_images <= $operation->{max_images}){
        print "FAIL\n" if $verbose;
        print "\nERROR - operation '$operation_name' requires ";
        if($operation->{min_images} == $operation->{max_images}){
            print "exactly $operation->{min_images}";
        }else{
            print "between $operation->{min_images} & $operation->{max_images}";
        }
        print " - you supplied $num_images\n\n";
        exit 1;
    }
}elsif($operation->{min_images}){
    # just min specified
    unless($num_images >= $operation->{min_images}){
        print "FAIL\n" if $verbose;
        print "\nERROR - operation '$operation_name' requires at least $operation->{min_images} - you supplied $num_images\n\n";
        exit 1;
    }
}
print "OK\n" if $verbose;

# deal with options
print 'INFO - consolidating options (combinig specified options with defaults) ... ' if $verbose;
my $consolidated_options; # a hashref of options with defaults used for unspecified options
foreach my $sup_opt (keys %{$operation->{options}}){
    if($options{$sup_opt}){
        $consolidated_options->{$sup_opt} = $options{$sup_opt};
    }else{
        $consolidated_options->{$sup_opt} = $operation->{options}->{$sup_opt};
    }
}
print "OK\nUsing Values:\n" if $verbose;
print Data::Dumper->Dump([$consolidated_options]) if $verbose;

# ask the user if they are sure (unless --yes or --debug)
unless($debug || $options{yes}){
    # if there are images spceified, warn that they are about to be overwritten
    if($num_images){
        print "You are about to execute the following operation:\n$operation_name - $operation->{description}\n";
        print "\nThis will result in the following images being overwritten:\n";
        foreach my $image (@images){
            print " - $image\n";
        }
        print "\nAre you sure you want to continue?\n";
        unless(prompt('y/n: ', -tyn)){
            exit 0;
        }
    }
}

#
# Initialise needed Objects
#

# create a WebifyIMG image processor
my $webify_cfg = {};
if($options{quiet}){
    $webify_cfg->{quiet} = 1;
}
my $webify = WebifyIMG->new($webify_cfg, $debug);

# create a Webify image set with the processor
my $image_set = WebifyIMG::ImageSet->new($webify, @images);

# call the function to do the actual work
&{$operation->{function}};

#
# Functions to implement the operations
#

# frame
sub _frame{
    $image_set->frame_simple(\%options);
    
    # to keep perlcritic happy
    return 1;
}

#
# Utility Functions
#
