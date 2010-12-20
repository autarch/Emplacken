package Emplacken::Types;

use strict;
use warnings;

use base 'MooseX::Types::Combine';

__PACKAGE__->provide_types_from(
    qw(
        Emplacken::Types::Internal
        MooseX::Types::Moose
        MooseX::Types::Path::Class
        MooseX::Types::Perl
        )
);

1;

# ABSTRACT: Exports Emplacken types as well as Moose and Path::Class types
