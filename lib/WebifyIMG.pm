package WebifyIMG;

use strict;
use warnings;
use Carp;
use Config::Simple; # from CPAN - for reading config files
use IO::CaptureOutput 'capture_exec'; # from CPAN - for executing shell commands
use String::ShellQuote; # from CPAN - for preparing strings for use in a shell

# version info
use version; our $VERSION = qv('0.1_3');

#
# CONSTANTS
#
our $_DEFAULT_INI_LOCATION = $ENV{HOME}.'/.WebifyIMG/WebifyIMG.cfg';
my $_CLASS = 'WebifyIMG';

#####-SUB-######################################################################
# Type       : CONSTRUCTOR (CLASS FUNCTION)
# Purpose    : Create a new instance of the WebifyIMG class
# Returns    : An instance of the WebifyIMG class
# Arguments  : 1) OPTIONAL - either a hashref with configuration options, or the
#                 path to a file in simplified INI format contiaining
#                 configuration options.
#              2) OPTIONAL - a boolean value to indicate whether or not to enter
#                 debug mode.
# Throws     : Carps in the case of file IO errors or invalid arguments
# Notes      : All configuration options are initialised with their default
#              values, then any values present in ~/.WebifyIMG/WebifyIMG.ini
#              override the default values, and then finally the values in the
#              hashref or specified file override any ecisting values.
# See Also   :
sub new{
    my $class = shift;
    my $config = shift;
    my $debug = shift;
    
    # validate args
    unless($class && $class eq $_CLASS){
        croak((caller 0)[3].'() - invalid arguments');
    }

    # create the instance with defaults
    my $instance = {
        imagemagick_bin_path => '/opt/local/bin/',
        font_caps => $ENV{HOME}.'/.WebifyIMG/capsFont.ttf',
        license_icon => $ENV{HOME}.'/.WebifyIMG/license.png',
        url => 'www.domain.com',
    };
    if($debug){
        $instance->{debug} = 1;
    }
    bless $instance, $class;
    
    # load config values from default ini file if it exists
    if(-f $_DEFAULT_INI_LOCATION){
        $instance->_debug("$_DEFAULT_INI_LOCATION found - loading ...");
        $instance->load($_DEFAULT_INI_LOCATION);
    }else{
        $instance->_debug("$_DEFAULT_INI_LOCATION not found");
    }
    
    # load config values from passed config (if one was passed)
    if($config){
        $instance->load($config);
    }
    
    #
    # TO DO - validate all file paths loaded
    #
    
    # return assembled instance
    return $instance;
}

#
# Accessor methods
#

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : Load configuration values from an ini file or hashref
# Returns    : The number of variables loaded from the file or hashref
# Arguments  : 1) the file or the hashref to load configuation variables from.
# Throws     : Croaks if no argument passed, Croaks on File IO error
sub load{
    my $self = shift;
    my $source = shift;
    
    # make sure we got valid arguments
    unless($self && $self->isa($_CLASS) && $source){
        croak((caller 0)[3].'() - invalid arguments - no source passed');
    }
    
    # extract the passed config
    my %new_opts;
    my $source_type = ref $source;
    if($source_type){
        # we were passed some kind of reference - now to make sure it's a hash
        if($source_type eq 'HASH'){
            # we got a hash
            %new_opts = %{$source};
            $self->_debug('source passed as hashref');
        }else{
            # we were passed an invalid kind of reference - get cranky!
            croak((caller 0)[3].'() - invalid arguments - invalid source passed');
        }
    }else{
        # we were passed a regular scalar, so treat as file path
        $self->_debug("source passed as scalar - interpreting as file path ($source)");
        unless(-f $source){
            croak((caller 0)[3]."() - invalid arguments - file $source does not exist");
        }
        Config::Simple->import_from($source, \%new_opts);
    }
    
    # loop through the valid config options and override any values
    # present in the loaded source
    my $num_loaded = 0;
    foreach my $opt (keys %{$self}){
        if(defined $new_opts{$opt}){
            $self->{$opt} = $new_opts{$opt};
            $self->_debug("set $opt=$new_opts{$opt}");
            $num_loaded++;
        }
    }
    
    # return count
    $self->_debug("loaded $num_loaded configuration options from $source");
    return $num_loaded;
}

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : Return the full path to the mogrify command (based on
#              imagemagick_bin_path config option).
# Returns    : The path to mogrify as a string
# Arguments  : NONE
# Throws     : Croaks on invalid args
sub bin_mogrify{
    my $self = shift;
    unless($self && $self->isa($_CLASS)){
        croak((caller 0)[3].'() - invalid arguments');
    }
    return $self->{imagemagick_bin_path}.'mogrify';
}

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : Return the full path to the convert command (based on
#              imagemagick_bin_path config option).
# Returns    : The path to convert as a string
# Arguments  : NONE
# Throws     : Croaks on invalid args
sub bin_convert{
    my $self = shift;
    unless($self && $self->isa($_CLASS)){
        croak((caller 0)[3].'() - invalid arguments');
    }
    return $self->{imagemagick_bin_path}.'convert';
}

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : Return the full path to the composite command (based on
#              imagemagick_bin_path config option).
# Returns    : The path to convert as a string
# Arguments  : NONE
# Throws     : Croaks on invalid args
sub bin_composite{
    my $self = shift;
    unless($self && $self->isa($_CLASS)){
        croak((caller 0)[3].'() - invalid arguments');
    }
    return $self->{imagemagick_bin_path}.'composite';
}

#
# Image processing functions
#

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : Add a border around an image
# Returns    : 1 if the operation was successful, 0 otherwise
# Arguments  : 1) the path to the image to add the border to
#              2) OPTIONAL - a hashref of options:
#                 colour - the colour to use for the border (default #999999)
#                 border - the width of the border in pixels (default 1)
# Throws     : Croaks on invalid args
sub add_border{
    my $self = shift;
    my $image = shift;
    my $opts = shift;
    
    # check we have valid args
    unless($self && $self->isa($_CLASS) && $image){
        croak((caller 0)[3].'() - invalid arguments');
    }
    
    # init options to defaults
    my $colour = '#999999';
    my $border = 1;
    
    # override with any passed options
    if ($opts->{colour}) {
        $colour = $opts->{colour};
    }
    if ($opts->{border} && $opts->{border} =~ m/^\d+$/sx) {
        $border = $opts->{border};
    }
    
    # prepare the arguments for use in the shell
    my $image_q = shell_quote($image);
    my $border_q = shell_quote($border.q{x}.$border); # convert to geomerty e.g. 1x1
    my $colour_q = shell_quote($colour);
    
    # shell out to ImageMagick
    if($self->_exec($self->bin_mogrify().qq{ -border $border_q -bordercolor $colour_q $image_q})){
        $self->_report("$image: added border (thickness=${border}px, colour=$colour)");
        return 1;
    }
    
    # if we get here we failed to add the border
    $self->_warn("$image: failed to add border");
    return 0;
}

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : Insert license icon into the lower left of the passed image
# Returns    : 1 if the operation was successful, 0 otherwise
# Arguments  : 1) the path to the image to add the border to
#              2) OPTIONAL - a hashref of options:
#                 opacity - the opacity to add the license icon with as an
#                           integer percentage (default 50)
# Throws     : Croaks on invalid args
sub insert_license_icon{
    my $self = shift;
    my $image = shift;
    my $opts = shift;
    
    # validate args
    unless($self && $self->isa($_CLASS) && $image){
        croak((caller 0)[3].'() - invalid arguments');
    }
    
    # init options to defaults
    my $opacity = 50;
    
    # override with any valid passed options
    if($opts->{opacity} && $opts->{opacity} =~ m/^\d+$/sx && $opts->{opacity} <= 100){
        $opacity = $opts->{opacity};
    }
    
    # prepare the arguments for use in the shell
    my $image_q = shell_quote($image);
    my $icon_q = shell_quote($self->{license_icon});
    
    # shell out to ImageMagick
    if($self->_exec($self->bin_composite().qq{ -watermark $opacity -gravity southwest -geometry +5+5 $icon_q $image_q $image_q})){
        $self->_report("$image: inserted license icon (opacity=${opacity}%)");
        return 1;
    }
    
    # if we get here we failed to insert the icon
    $self->_warn("$image: failed to insert license icon");
    return 0;
}

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : Insert URL in white into the lower-right of the given image
# Returns    : 1 if the operation was successful, 0 otherwise
# Arguments  : 1) the path to the image to insert the URL into
#              2) OPTIONAL - a hashref of options:
#                 opacity - the opacity of the URL text as an integer
#                            percentage (default 50)
# Throws     : Croaks on invalid args
# Notes      : TO DO - find a nice way to take an RGB colour as an argument
sub insert_url{
    my $self = shift;
    my $image = shift;
    my $opts = shift;
    
    # validate args
    unless($self && $self->isa($_CLASS) && $image){
        croak((caller 0)[3].'() - invalid arguments');
    }
    
    # init options to defaults
    my $opacity = 50;
    
    # override with any valid passed options
    if($opts->{opacity} && $opts->{opacity} =~ m/^\d+$/sx && $opts->{opacity} <= 100){
        $opacity = $opts->{opacity};
    }
    # TO DO - find a way to nicely take RGB colour input
    
    # prepare the arguments for use in the shell
    my $opacity_d = $opacity/100; # convert to a decimal
    my $image_q = shell_quote($image);
    my $font_q = shell_quote($self->{font_caps});
    my $url_q = shell_quote($self->{url});
    
    # shell out to ImageMagick
    if($self->_exec($self->bin_mogrify().qq{ -fill 'rgba(255, 255, 255, $opacity_d)' -pointsize 14 -font $font_q -gravity southeast -annotate +7+4 $url_q $image_q})){
        $self->_report("$image: inserted URL (opacity=${opacity}%)");
        return 1;
    }
    
    # if we get here we failed to insert the icon
    $self->_warn("$image: failed to insert URL");
    return 0;
}

#
# private helper functions
#

#####-SUB-######################################################################
# Type       : INSTANCE (PRIVATE)
# Purpose    : to execute a shell command - anything to STDOUT gets printed
# Returns    : 1 if successfull, 0 otherwise
# Arguments  : the string to execute
# Throws     : Croaks on invalid args, carps if anything written to STDERR
sub _exec{
    my $self = shift;
    my $command = shift;
    
    # validate args
    unless($self && $self->isa($_CLASS) && $command){
        croak((caller 0)[3].'() - invalid arguments');
    }
    
    # if we're debugging, just print the command that would be executed, and return success
    if ($self->{debug}) {
        $self->_debug("would execute: $command");
        return 1;
    }
    
    # do the shelling out
    my ($stdout, $stderr, $success, $exit_code) = capture_exec($command);
    
    # if anything was written to stdout, print it
    if ($stdout) {
        print $stdout;
    }
    
    # if anything was written to STDERR, carp about it
    if ($stderr) {
        carp((caller 0)[3]."() - $stderr");
    }
    
    # return success or failure
    if ($success) {
        return 1;
    }
    return 0;
}

#####-SUB-######################################################################
# Type       : INSTANCE (PRIVATE)
# Purpose    : print debug message if in debug mode
# Returns    : always returns 1
# Parameters : 1) The message to print
# Throws     : NOTHING
sub _debug{
    my $self = shift;
    my $message = shift;
    
    # validate args
    unless($self && $self->isa($_CLASS) && defined $message){
        croak((caller 0)[3].'() - invalid arguments');
    }
    
    # print the message if in debug mode
    if($self->{debug}){
        print 'DEBUG - '.(caller 1)[3]."() - $message\n";
    }
    
    # return a true value to keep perlcritic happy
    return 1;
}

#####-SUB-######################################################################
# Type       : INSTANCE (PRIVATE)
# Purpose    : To report results of image processing functions (unless option
#              quiet is set to a true value).
# Returns    : Always returns 1
# Arguments  : The message to print
# Throws     : Croaks on invalid arguments
sub _report{
    my $self = shift;
    my $message = shift;
    unless($self && $self->isa($_CLASS) && $message){
        croak((caller 0)[3].'() - invalid arguments');
    }
    unless($self->{quiet}){
        print "WebifyIMG - $message\n";
    }
    return 1; # to keep perlcritic happy
}

#####-SUB-######################################################################
# Type       : INSTANCE (PRIVATE)
# Purpose    : Print a warning on image processing error.
# Returns    : always returns 1.
# Arguments  : the warning message to print.
# Throws     : Croaks on invalid args.
# Notes      : the warning is reported as coming from the calling function.
sub _warn{
    my $self = shift;
    my $message = shift;
    
    # validate args
    unless($self && $self->isa($_CLASS)){
        carp("WebifyIMG - $message (".(caller 1)[3].")\n");
    }
    
    # always return true to keep perlcritic happy
    return 1;
}

1; # because Perl is a bit special!

__END__

=pod

=head1 NAME

WebifyIMG Ð A Perl module for preparing images for posting to the web

=head1 VERSION

This documentation refers to WebifyIMG version 0.1.

=head1 SYNOPSIS

    # TO DO

=head1 DESCRIPTION

Lots to do here!

=head1 SUBROUTINES/METHODS

Lots to do here too!

=head1 CONFIGURATION AND ENVIRONMENT

Describe .ini files here

=head1 DEPENDENCIES

=head2 CPAN MODULES

This module requires the following CPAN modules:

=over

=item * C<Config::Simple> - L<http://search.cpan.org/perldoc?Config%3A%3ASimple>

=item * C<IO::CaptureOutput> - L<http://search.cpan.org/perldoc?IO%3A%3ACaptureOutput>

=item * C<String::ShellQuote> - L<http://search.cpan.org/perldoc?String%3A%3AShellQuote>

=back

=head2 BINARIES

This module requires that the ImageMagick binaries be installed.

=head1 INCOMPATIBILITIES

This module has no known incompatibilities.

=head1 BUGS AND LIMITATIONS

This module expects to be running on a Linux/Unix system (including OS X), it will not work on Windows without something like Cygwin.

Please report bugs to Bart Busschots (L<mailto:bart@bartificer.net>).

Patches are welcome via a pull request on GitHub - L<https://github.com/bbusschots/WebifyIMG>

=head1 AUTHOR

Bart Busschots (L<mailto:bart@bartificer.net>)

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2013 onwards Bart Busschots (L<mailto:bart@bartificer.net>). All rights reserved.

This software is released under the L<GPL V2 license|http://www.gnu.org/licenses/gpl-2.0.html>