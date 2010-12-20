package Emplacken::App::Starman;

use Moose;

use namespace::autoclean;

use Emplacken::Types qw( Bool Int );

extends 'Emplacken::App';

has pid_file => (
    is        => 'ro',
    isa       => File,
    coerce    => 1,
);

has workers => (
    is        => 'ro',
    isa       => Int,
    predicate => '_has_workers',
);

has disable_keepalive => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

override _command_line => sub {
    my $self = shift;

    my @cli = super();

    push @cli, '--workers', $self->workers()
        if $self->_has_workers();

    push @cli, '--disable-keepalive'
        if $self->disable_keepalive();

    push @cli, '--user', $self->user()
        if $self->_has_user();

    push @cli, '--group', $self->group()
        if $self->_has_group();

    push @cli, '--pid', $self->pid_file();

    return @cli;
};

# The Starman server handles tihs itself
override _set_uid => sub { };
override _set_gid => sub { };

sub manages_pid_file { 1 }

__PACKAGE__->meta()->make_immutable();

1;
