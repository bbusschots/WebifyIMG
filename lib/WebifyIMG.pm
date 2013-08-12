package WebifyIMG;

use strict;
use warnings;
use Carp;
use Config::Simple; # from CPAN - for reading config files

# version info
use version; our $VERSION = qv('0.1_2');

#
# CONSTANTS
#
our $_DEFAULT_INI_LOCATION = '~/.WebifyIMG/WebifyIMG.ini';

#####-SUB-######################################################################
# Type       : CONSTRUCTOR (CLASS FUNCTION)
# Purpose    : Create a new instance of the WebifyIMG class
# Returns    : An instance of the WebifyIMG class
# Arguments  : 1) OPTIONAL - either a hashref with configuration options, or the
#                 path to a file in simplified INI format contiaining
#                 configuration options.
#              2) OPTIONAL - a boolean value to indicate whether or not to enter
#                 debug mode.
# Throws     : Carps in the case of file IO errors
# Notes      : All configuration options are initialised with their default
#              values, then any values present in ~/.WebifyIMG/WebifyIMG.ini
#              override the default values, and then finally the values in the
#              hashref or specified file override any ecisting values.
# See Also   :
sub new{
    my $class = shift;
    my $config = shift;
    my $debug = shift;

    # create the instance with defaults
    my $instance = {
        imagemagick_bin_path => '/opt/local/bin/',
        license_icon => '~/.WebifyIMG/license.png',
        url => 'www.bartb.ie',
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
    
    # return assembled instance
    return $instance;
}

#####-SUB-######################################################################
# Type       : INSTANCE
# Purpose    : Load configuration values from an ini file or hashref.
# Returns    : The number of variables loaded from the file or hashref
# Arguments  : 1) the file or the hashref to load configuation variables from.
# Throws     : Croaks if no argument passed, Croaks on File IO error
sub load{
    my $self = shift;
    my $source = shift;
    
    # make sure we got valid arguments
    unless($source){
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

#
# private helper functions
#

#####-SUB-######################################################################
# Type       : INSTANCE (PRIVATE)
# Purpose    : print debug message if in debug mode
# Returns    : always returns 1
# Parameters : 1) The message to print
# Throws     : NOTHING
sub _debug{
    my $self = shift;
    my $message = shift;
    
    # print the message if in debug mode
    if($self->{debug}){
        print 'DEBUG - '.(caller 1)[3]."() - $message\n";
    }
    
    # return a true value to keep perlcritic happy
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