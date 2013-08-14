package WebifyIMG::ImageSet;

use strict;
use warnings;
use Carp;

# version info
use version; our $VERSION = qv('0.1_1');

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

1; # because Perl is a bit special!

__END__