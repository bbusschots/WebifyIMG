package WebifyIMG::ImageSet;

use strict;
use warnings;
use Carp;

# version info
use version; our $VERSION = qv('0.1_3');

#
# CONSTANTS
#
my $_CLASS = 'WebifyIMG::ImageSet';

#####-SUB-######################################################################
# Type       : CONSTRUCTOR (CLASS FUNCTION)
# Purpose    : Create a new instance of the WebifyIMG::ImageSet class
# Returns    : An instance of the WebifyIMG::ImageSet class
# Arguments  : 1) A WebifyIMG object
#              2) OPTIONAL, a list of image paths to initialise the object with
# Throws     : Croaks on invalid args
sub new{
    my $class = shift;
    my $processor = shift;
    
    # validate args
    unless($class && $class eq $_CLASS && $processor && $processor->isa('WebifyIMG')){
        croak((caller 0)[3].'() - invalid arguments');
    }

    # create an instance
    my $instance = {
        processor => $processor, # a WebifyIMG object to do any needed image processing
        images => [], # and array ref of image paths (as strings)
    };
    bless $instance, $class;
    
    # load any image paths passed as arguments
    while(my $image = shift){
        $instance->add_images($image);
    }
    
    # return assembled instance
    return $instance;
}

#
# accessor methods
#

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : Access the arrayref of image paths stored in the object
# Returns    : an array ref to an array of strings
# Arguments  : NONE
# Throws     : Croaks on invalid args
sub images{
    my $self = shift;
    
    # validate args
    unless($self && $self->isa($_CLASS)){
        croak((caller 0)[3].'() - invalid arguments');
    }
    
    # return the array ref
    return $self->{images};
}

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : add one or more image paths to self
# Returns    : self - to allow the function be chanined
# Arguments  : A list of image pathss to append to images array ref
# Throws     : Croaks on invalid args
sub add_images{
    my $self = shift;
    
    # validate args
    unless($self && $self->isa($_CLASS)){
        croak((caller 0)[3].'() - invalid arguments');
    }
    
    # process the image paths to be added
    while(my $image = shift){
        push @{$self->{images}}, $image;
    }
    
    # return self
    return $self;
}

#
# Chainable Image Processing Functions
#

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : Add a simple coloured border to the images in this set.
# Returns    : self (to allow chaining of operations)
# Arguments  : OPTIONAL - a hashref with options
# Throws     : Croaks on invalid arguments
# See Also   : Valid options and defaults defined by WebifyIMG::add_borer()
sub add_border{
    my $self = shift;
    my $opts = shift;
    return $self->_process(\&WebifyIMG::add_border, $opts);
}

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : Insert license icon into lower-left of the images in this set.
# Returns    : self (to allow chaining of operations)
# Arguments  : OPTIONAL - a hashref with options
# Throws     : Croaks on invalid arguments
# See Also   : Valid options and defaults defined by WebifyIMG::insert_license_icon()
sub insert_license_icon{
    my $self = shift;
    my $opts = shift;
    return $self->_process(\&WebifyIMG::insert_license_icon, $opts);
}

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : Insert a translucent strip along the bottom of the images in
#              this set.
# Returns    : self (to allow chaining of operations)
# Arguments  : OPTIONAL - a hashref with options
# Throws     : Croaks on invalid arguments
# See Also   : Valid options and defaults defined by WebifyIMG::insert_strip()
sub insert_strip{
    my $self = shift;
    my $opts = shift;
    return $self->_process(\&WebifyIMG::insert_strip, $opts);
}

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : Insert URL into lower-right of the images in this set.
# Returns    : self (to allow chaining of operations)
# Arguments  : OPTIONAL - a hashref with options
# Throws     : Croaks on invalid arguments
# See Also   : Valid options and defaults defined by WebifyIMG::insert_url()
sub insert_url{
    my $self = shift;
    my $opts = shift;
    return $self->_process(\&WebifyIMG::insert_url, $opts);
}

#
# Private helper functions
#

#####-SUB-######################################################################
# Type       : INSTANCE (PRIVATE)
# Purpose    : execute an image processing function on a set of images
# Returns    : self (to facilitate chaining)
# Arguments  : 1) a coderef to the function to execute on all the images. The
#              function must be an instance function of WebifyIMG.
#              2) OPTIONAL - an options hashref with valid options for what ever
#              function is being invoked.
# Throws     : Croaks on invalid args, Called functions Carps on shell errors
# Notes      : errors processing images are reported as coming form the caller
#              of this private utility function.
sub _process{
    my $self = shift;
    my $sub = shift;
    my $opts = shift;
    
    #
    # validate args
    #
    
    # make sure we are being called as an instance function
    unless($self && $self->isa($_CLASS)){
        croak((caller 0)[3].'() - not called as an instance function');
    }
    
    # make sure we really did get a code ref as the second argument
    unless($sub && (ref $sub) eq 'CODE'){
        croak((caller 0)[3].'() - did not receive needed code ref (called by '.(caller 1)[3].')');
    }
    
    # if a third argument was passed, make sure it really is a hashref
    if(defined $opts){
        unless((ref $opts) eq 'HASH'){
            croak((caller 0)[3].'() - options argument was not a hashref (called by '.(caller 1)[3].')');
        }
    }
    
    #
    # call the provided function on each image in self
    #
    foreach my $image (@{$self->{images}}){
        unless(&{$sub}($self->{processor}, $image, $opts)){
            carp((caller 1)[3]."() - an error occoured processing $image");
        }
    }
    
    # finally return self (to facilitate chaining)
    return $self
}

1; # because Perl is a bit special!

__END__