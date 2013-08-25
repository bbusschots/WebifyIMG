package WebifyIMG;

use strict;
use warnings;
use Carp;
use Config::Simple; # from CPAN - for reading config files
use IO::CaptureOutput 'capture_exec'; # from CPAN - for executing shell commands
use String::ShellQuote; # from CPAN - for preparing strings for use in a shell
# use Data::Dumper; # TEMP FOR DEBUGGING

# version info
use version; our $VERSION = qv('1.0');

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
        font_cursive => $ENV{HOME}.'/.WebifyIMG/cursiveFont.ttf',
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
# Purpose    : Return the full path to the identify command (based on
#              imagemagick_bin_path config option).
# Returns    : The path to convert as a string
# Arguments  : NONE
# Throws     : Croaks on invalid args
sub bin_identify{
    my $self = shift;
    unless($self && $self->isa($_CLASS)){
        croak((caller 0)[3].'() - invalid arguments');
    }
    return $self->{imagemagick_bin_path}.'identify';
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

#
# Image Querying Functions
#

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : Get the width and height of an image in pixels
# Returns    : a hashref indexed by width and height
# Arguments  : The image to get the dimensions of
# Throws     : Croaks on invalid args or if no height was returned
sub image_dimensions{
    my $self = shift;
    my $image = shift;
    
    # check we have valid args
    unless($self && $self->isa($_CLASS) && $image){
        croak((caller 0)[3].'() - invalid arguments');
    }
    
    # prepare the arguments for use in the shell
    my $image_q = shell_quote($image);
    
    # shell out to ImageMagick
    my $ans = q{}; # an empty string
    $ans = $self->_exec($self->bin_identify().q{ -format '%wx%h' }.$image_q, {stdout => 1, force => 1, croak => 1, quiet => 1});
    chomp $ans;
    $self->_debug("$image: raw dimensions=$ans");
    
    # extract the data and return if we can
    if($ans =~ m/^(\d+)x(\d+)$/sx){
        $self->_debug("$image: width=$1, height=$2");
        return {
            width => $1,
            height => $2,
        }
    }
    
    # if we got here something has gone wrong
    croak((caller 0)[3].' - received invalid answer from '.$self->bin_identify());
}



#
# Atomic Image processing functions
#

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : add vertical or horizontal bars to an image.
# Returns    : 1 if the operation was successful, 0 otherwise
# Arguments  : 1) the path to the image to add the bars to
#              2) OPTONAL - a hashref of options:
#                 orientation - 'vertical' or 'horizontal' (defaul=horizontal)
#                 border - the thickness of the bars (default=1)
#                 colour - the colour of the bars (default=#ffffff)
# Throws     : Croaks on invalid args
sub add_bars{
    my $self = shift;
    my $image = shift;
    my $opts = shift;
    
    # check we have valid args
    unless($self && $self->isa($_CLASS) && $image){
        croak((caller 0)[3].'() - invalid arguments');
    }
    
    # init options to defaults
    my $alignment = 'horizontal';
    my $thickness = 1;
    my $colour = '#ffffff';
    
    # override with any passed options
    if($opts->{orientation} && lc $opts->{orientation} eq 'vertical') {
        $alignment = 'vertical';
    }
    if($opts->{border} && $opts->{border} =~ m/^\d+$/sx){
        $thickness = $opts->{border};
    }
    if($opts->{colour}){
        $colour = $opts->{colour};
    }
    
    # prepare the arguments for use in the shell
    my $image_q  = shell_quote($image);
    my $colour_q = shell_quote($colour);
    
    # add thin border
    my $geometry = '0x'.$thickness;
    if($alignment eq 'vertical'){
        $geometry = $thickness.'x0';
    }
    
    # shell out to ImageMagick
    if($self->_exec($self->bin_mogrify().qq{ -border $geometry -bordercolor $colour_q $image_q})){
        $self->_report("$image: added $alignment bars (thickness=${thickness}px & colour=$colour)");
        return 1;
    }
    
    # if we get here we failed to add the bars
    $self->_warn("$image: failed to add bars");
    return 0;
}

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
#                 gravity - a valid ImageMagick gravity (default southwest)
#                 offset  - a valid ImageMagick geometry (default +5+5)
# Throws     : Croaks on invalid args
sub insert_license_icon{
    my $self  = shift;
    my $image = shift;
    my $opts  = shift;
    
    # validate args
    unless($self && $self->isa($_CLASS) && $image){
        croak((caller 0)[3].'() - invalid arguments');
    }
    
    # init options to defaults
    my $opacity = 50;
    my $gravity = 'southwest';
    my $offset  = '+5+5';
    
    # override with any valid passed options
    if($opts->{opacity} && $opts->{opacity} =~ m/^\d+$/sx && $opts->{opacity} <= 100){
        $opacity = $opts->{opacity};
    }
    if($opts->{gravity} && $self->valid_gravity($opts->{gravity})){
        $gravity = $opts->{gravity};
    }
    if(defined $opts->{offset} && $self->valid_geometry($opts->{offset})){
        $offset = $opts->{offset};
    }
    
    # prepare the arguments for use in the shell
    my $image_q   = shell_quote($image);
    my $icon_q    = shell_quote($self->{license_icon});
    my $gravity_q = shell_quote($gravity);
    my $offset_q  = shell_quote($offset);
    
    # shell out to ImageMagick
    if($self->_exec($self->bin_composite().qq{ -watermark $opacity -gravity $gravity_q -geometry $offset_q $icon_q $image_q $image_q})){
        $self->_report("$image: inserted license icon (opacity=${opacity}%)");
        return 1;
    }
    
    # if we get here we failed to insert the icon
    $self->_warn("$image: failed to insert license icon");
    return 0;
}

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : Insert a partially transparent black strip over the bottom of
#              an image.
# Returns    : 1 if the operation was successful, 0 otherwise
# Arguments  : 1) the path to the image to insert the strip into
#              2) OPTIONAL - a hashref of options:
#                 opacity - the opacity of the strip text as an integer
#                            percentage (default 50)
# Throws     : Croaks on invalid args
# Notes      : TO DO - find a nice way to take an RGB colour as an argument
sub insert_strip{
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
    
    # calculate the geometry of the strip
    my $dim = $self->image_dimensions($image);
    my $rectangle = 'rectangle 0,'.($dim->{height} - 25)." $dim->{width},$dim->{height}";
    
    # prepare the arguments for use in the shell
    my $opacity_d = $opacity/100; # convert to a decimal
    my $image_q = shell_quote($image);
    
    # shell out to ImageMagick
    if($self->_exec($self->bin_mogrify().qq{ -fill 'rgba(0, 0, 0, $opacity_d)' -draw '$rectangle' $image_q})){
        $self->_report("$image: inserted translucent strip (opacity=${opacity}%)");
        return 1;
    }
    
    # if we get here we failed to insert the icon
    $self->_warn("$image: failed to insert translucent strip");
    return 0;
}

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : Insert text into an image
# Returns    : 1 if the operation was successful, 0 otherwise
# Arguments  : 1) the image to insert the text into
#              2) the text to insert
#              3) OPTIONAL - a hashref of options
#                 colour    - the colour of the text (default='#cccccc')
#                 font      - the path to the font to use
#                             (default=$self->{font_cursive})
#                 font_size - the size of the font in pts (default=20)
#                 gravity   - a valid ImageMagick gravity (default='south')
#                 offset    - a valid ImageMagic geometry (default='+0+0')
# Throws     : Croaks on invalid args
sub insert_text{
    my $self  = shift;
    my $image = shift;
    my $text  = shift;
    my $opts  = shift;
    
    # validate args
    unless($self && $self->isa($_CLASS) && $image && (length $text)){
        croak((caller 0)[3].'() - invalid arguments');
    }
    
    # init options to defaults
    my $colour    = '#cccccc';
    my $font      = $self->{font_cursive};
    my $font_size = 20;
    my $gravity   = 'south';
    my $offset    = '+0+0';
    
    # override and passed options
    if($opts->{colour}){ ## TO DO - better validation
        $colour = $opts->{colour};
    }
    if($opts->{font} && $self->valid_font($opts->{font})){
        $font = $opts->{font};
    }
    if($opts->{font_size} && $opts->{font_size} =~ m/^\d+$/sx){
       $font_size = $opts->{font_size}; 
    }
    if($opts->{gravity} && $self->valid_gravity($opts->{gravity})){
        $gravity = $opts->{gravity};
    }
    if(defined $opts->{offset} && $self->valid_geometry($opts->{offset})){
       $offset = $opts->{offset}; 
    }
    
    # prepare arguments for shell
    my $image_q     = shell_quote($image);
    my $text_q      = shell_quote($text);
    my $colour_q    = shell_quote($colour);
    my $font_q      = shell_quote($font);
    my $font_size_q = shell_quote($font_size);
    my $gravity_q   = shell_quote($gravity);
    my $offset_q    = shell_quote($offset);
    
    # shell out to image magic
    if($self->_exec($self->bin_mogrify().qq{ -fill $colour_q -pointsize $font_size_q -font $font_q -gravity $gravity_q -annotate $offset_q $text_q $image_q})){
        $self->_report(qq{$image: inserted text "$text"});
        return 1;
    }
    
    # if we got here we failed to insert the text
    $self->_warn("$image: failed to insert text");
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
#                 gravity - a valid Image Magick gravity (default southeast)
#                 offset  - a valid Image Magick geometry (default +7+4)
# Throws     : Croaks on invalid args
# Notes      : TO DO - find a nice way to take an RGB colour as an argument
sub insert_url{
    my $self  = shift;
    my $image = shift;
    my $opts  = shift;
    
    # validate args
    unless($self && $self->isa($_CLASS) && $image){
        croak((caller 0)[3].'() - invalid arguments');
    }
    
    # init options to defaults
    my $opacity = 50;
    my $gravity = 'southeast';
    my $offset  = '+7+4';
    
    # override with any valid passed options
    if($opts->{opacity} && $opts->{opacity} =~ m/^\d+$/sx && $opts->{opacity} <= 100){
        $opacity = $opts->{opacity};
    }
    # TO DO - find a way to nicely take RGB colour input
    if($opts->{gravity} && $self->valid_gravity($opts->{gravity})){
        $gravity = $opts->{gravity};
    }
    if(defined $opts->{offset} && $self->valid_geometry($opts->{offset})){
        $offset = $opts->{offset};
    }
    
    # prepare the arguments for use in the shell
    my $opacity_d = $opacity/100; # convert to a decimal
    my $image_q   = shell_quote($image);
    my $font_q    = shell_quote($self->{font_caps});
    my $url_q     = shell_quote($self->{url});
    my $gravity_q = shell_quote($gravity);
    my $offset_q  = shell_quote($offset);
    
    # shell out to ImageMagick
    if($self->_exec($self->bin_mogrify().qq{ -fill 'rgba(255, 255, 255, $opacity_d)' -pointsize 14 -font $font_q -gravity $gravity_q -annotate $offset_q $url_q $image_q})){
        $self->_report("$image: inserted URL (opacity=${opacity}%)");
        return 1;
    }
    
    # if we get here we failed to insert the icon
    $self->_warn("$image: failed to insert URL");
    return 0;
}

#
# Composite Image Processing Functions
#

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : Frame an image with vertical or horizontal bars with license
#              icon, url, and optionally a title.
# Returns    : always returns 1
# Arguments  : 1) the path to the image to insert the URL into
#              2) OPTIONAL - a hashref of options:
#                 orientation - 'vertical' or 'horizontal'
#                 colour      - the colour for the fine border between the
#                               image and the bars (default=#ffffff)
#                 bgcolour    - the colour of the bars (default=#000000)
#                 tcolour     - the colour of the text for the title
#                               (default=#cccccc)
#                 title       - an optional title to insert into the bars
#                               (defaults to none)
# Throws     : Croaks on invalid arguments
sub frame_bars{
    my $self  = shift;
    my $image = shift;
    my $opts  = shift;
    
    # validate args
    unless($self && $self->isa($_CLASS) && $image){
        croak((caller 0)[3].'() - invalid arguments');
    }
    
    # init options to defaults
    my $orientation = 'horizontal';
    my $colour      = '#ffffff';
    my $bgcolour    = '#000000';
    my $tcolour     = '#cccccc';
    my $title       = q{}; # empty string
    
    # override defaults with valid passed options
    if($opts->{orientation} && lc $opts->{orientation} eq 'vertical') {
        $orientation = 'vertical';
    }
    if($opts->{colour}){
        $colour = $opts->{colour};
    }
    if($opts->{bgcolour}){
        $bgcolour = $opts->{bgcolour};
    }
    if($opts->{tcolour}){
        $tcolour = $opts->{tcolour};
    }
    if(length $opts->{title}){
       $title = $opts->{title}; 
    }
    
    # prepare args for shelling out
    my $image_q    = shell_quote($image);
    my $colour_q   = shell_quote($colour);
    my $bgcolour_q = shell_quote($bgcolour);
    my $tcolour_q  = shell_quote($tcolour);
    my $title_q    = shell_quote($title);
    my $font_q     = shell_quote($self->{font_cursive});
    
    # get image dimensions
    my $dim = $self->image_dimensions($image);
    
    # Add the bars
    $self->add_bars($image, {border => 1, colour => $colour, orientation => $orientation});
    my $thickness = 60;
    if($orientation eq 'vertical'){
        $thickness = 120;
    }
    $self->add_bars($image, {border => $thickness, colour => $bgcolour, orientation => $orientation});
    
    # Add the license icon
    if($orientation eq 'vertical'){
        $self->insert_license_icon($image, {opacity => 50, offset => '+20+5', gravity => 'southeast'});
    }else{
        $self->insert_license_icon($image, {opacity => 50});
    }
    
    # add the url
    if($orientation eq 'vertical'){
        my $x_offset = $dim->{width} + 135;
        my $offset = q{90x90+}.$x_offset.q{+5};
        $self->insert_url($image, {opacity => 50, gravity => 'northwest', offset => $offset});
    }else{
        $self->insert_url($image, {opacity => 50});
    }
    
    # if there was a title, add it
    if(length $title){
        my $text_geometry  = '+7+25';
        my $text_size      = 17;
        my $gravity        = 'southeast';
        if($orientation eq 'vertical'){
            $text_geometry = '270x270+99+7';
            $text_size     = 20;
            $gravity       = 'southwest';
        }
        $self->insert_text($image, $title, {colour => $tcolour, font => $self->{font_cursive}, font_size => $text_size, offset => $text_geometry, gravity => $gravity});
    }
    
    # finally, frame the lot
    $self->add_border($image, {border => 1, colour => '#999999'});
    
    # to keep perlcritic happy
    return 1;
}

#
# Validation functions
#

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : To Validate a font path
# Returns    : 1 if valid, 0 otherwise
# Arguments  : 1) The value to validate
#              2) OPTIONAL - a hashref of options:
#                 quiet - a true value means no output will be printed on
#                 failed validation
# Throws     : NOTHING
# Notes      : When debugging both success and faulure will be printed, when not
#              debugging only failure will be reported, unless the quiet option
#              is set in which case that output will be supressed.
sub valid_font{
    my $self = shift;
    my $font = shift;
    my $opts = shift;
    if($font && -f $font && $font =~ m/[.](otf)|(ttf)$/sx){
        $self->_debug("'$font' is valid");
        return 1;
    }
    if($self->{debug}){
        $self->_debug("'$font' is NOT valid");
    }else{
        unless($opts && $opts->{quiet}){
            $self->_warn("INVALID font '$font'");
        }
    }
    return 0;
}

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : To Validate an ImageMagick geometry
# Returns    : 1 if valid, 0 otherwise
# Arguments  : 1) The value to validate
#              2) OPTIONAL - a hashref of options:
#                 quiet - a true value means no output will be printed on
#                 failed validation
# Throws     : NOTHING
# Notes      : When debugging both success and faulure will be printed, when not
#              debugging only failure will be reported, unless the quiet option
#              is set in which case that output will be supressed.
sub valid_geometry{
    my $self = shift;
    my $geo  = shift;
    my $opts = shift;
    if($geo && $geo =~ m/^(\d+x\d+)?([+-]\d+){2}$/sx){
        $self->_debug("'$geo' is valid");
        return 1;
    }
    if($self->{debug}){
        $self->_debug("'$geo' is NOT valid");
    }else{
        unless($opts && $opts->{quiet}){
            $self->_warn("INVALID geometry '$geo'");
        }
    }
    return 0;
}

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : To validate an ImageMagick gravity
# Returns    : 1 if valid, 0 otherwise
# Arguments  : 1) The value to validate
#              2) OPTIONAL - a hashref of options:
#                 quiet - a true value means no output will be printed on
#                 failed validation
# Throws     : NOTHING
# Notes      : When debugging both success and faulure will be printed, when not
#              debugging only failure will be reported, unless the quiet option
#              is set in which case that output will be supressed.
sub valid_gravity{
    my $self =    shift;
    my $gravity = shift;
    my $opts =    shift;
    my $valid_gravities = {
        north     => 1,
        northeast => 1,
        east      => 1,
        southeast => 1,
        south     => 1,
        southwest => 1,
        west      => 1,
        northwest => 1,
    };
    if($gravity && $valid_gravities->{$gravity}){
        $self->_debug("'$gravity' is valid");
        return 1;
    }
    if($self->{debug}){
        $self->_debug("'$gravity' is NOT valid");
    }else{
        unless($opts && $opts->{quiet}){
            $self->_warn("INVALID gravity '$gravity'");
        }
    }
    return 0;
}

#
# private helper functions
#

#####-SUB-######################################################################
# Type       : INSTANCE (PRIVATE)
# Purpose    : to execute a shell command - anything to STDOUT gets printed
# Returns    : 1 if successfull, 0 otherwise, unless option stdout passed, in
#              which case the content of stdout is returned.
# Arguments  : 1) the string to execute
#              2) OPTIONAL - an options hashref indexed by:
#                 croak   - do croak unless success
#                 default - what to return when debugging with stdout set
#                 force   - execution even in debug mode
#                 quiet   - do not print stdout
#                 stdout  - return stdout rather than 1 or 0
# Throws     : Croaks on invalid args, carps if anything written to STDERR
sub _exec{
    my $self = shift;
    my $command = shift;
    my $opts = shift;
    
    # validate args
    unless($self && $self->isa($_CLASS) && $command){
        croak((caller 0)[3].'() - invalid arguments');
    }
    
    # if we're debugging, just print the command that would be executed, and return success
    if ($self->{debug} && !($opts && $opts->{force})) {
        $self->_debug("would execute: $command");
        if($opts && $opts->{stdout} && defined $opts->{default}){
            return $opts->{default};
        }
        return 1;
    }
    
    # do the shelling out
    my ($stdout, $stderr, $success, $exit_code) = capture_exec($command);    
    
    # if anything was written to stdout, print it
    unless($opts && $opts->{quiet}){
        print $stdout if $stdout;
    }
    
    # if anything was written to STDERR, carp about it
    if ($stderr) {
        carp((caller 0)[3]."() - $stderr");
    }
    
    # if in stdout mode, return stdout
    if($opts && $opts->{stdout}){
        return $stdout;
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