package WebifyIMG;

use strict;
use warnings;

# version info
use version; our $VERSION = qv('0.1_1');

=pod

=head1 NAME

WebifyIMG

=head1 SYNOPSIS

A Perl module for preparing images for posting on the web.

=head1 CONSTRUCTOR
=head2 ARGUMENTS
<B NONE>

e.g.

    my $webify = WebifyIMG->new()
=cut
sub new{
    my $class = shift;

    my $instance = {};
    bless $instance, $class;
    
    return $instance;
}

=pod
=head1 FUNCTIONS
=cut

1; # because Perl is a bit special!

