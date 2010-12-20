package Emplacken;

use Moose;

use Class::Load qw( is_class_loaded try_load_class );
use Config::Any;
use Emplacken::App;
use Emplacken::Types qw( ArrayRef Bool Dir File );
use Getopt::Long;
use List::AllUtils qw( first );

with 'MooseX::Getopt::Dashes';

Getopt::Long::Configure('pass_through');

has dir => (
    is      => 'ro',
    isa     => Dir,
    coerce  => 1,
    default => '/etc/emplacken',
);

has file => (
    is        => 'ro',
    isa       => File,
    coerce    => 1,
    predicate => '_has_file',
);

has verbose => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has __psgi_apps => (
    traits   => ['Array'],
    is       => 'ro',
    isa      => ArrayRef ['Emplacken::App'],
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_psgi_apps',
    handles  => {
        _psgi_apps => 'elements',
        _app_count => 'count',
    },
);

sub run {
    my $self = shift;

    my $command = $self->extra_argv()->[0] || 'start';
    my $meth = q{_} . $command;

    unless ( $self->can($meth) ) {
        die "Invalid command for emplacken: $command\n";
    }

    unless ( $self->_app_count() ) {
        if ( $self->_has_file() ) {
            die $self->file() . " is not a PSGI application config file\n";
        }
        else {
            die "Did not find any PSGI application config files in "
                . $self->dir() . "\n";
        }
    }

    if ( $self->$command() ) {
        _exit(0);
    }
    else {
        _exit(1);
    }
}

# This is a sub so we can override it for testing
sub _exit {
    exit shift;
}

sub _start {
    my $self = shift;

    return $self->_run_for_all_apps('start');
}

sub _stop {
    my $self = shift;

    return $self->_run_for_all_apps('start');
}

sub _restart {
    my $self = shift;

    return $self->_run_for_all_apps('stop')
        + $self->_run_for_all_apps('start');
}

sub _run_for_all_apps {
    my $self = shift;
    my $meth = shift;

    my $failed = 0;
    for my $app ( $self->_psgi_apps() ) {

        my $result = $app->$meth() ? 'OK' : 'failed';

        my $message = sprintf(
            "    %50s ... [%s]\n",
            "${meth}ing " . $app->name(),
            $result
        );

        $self->_maybe_print($message);
    }

    return !$failed;
}

sub _status {
    my $self = shift;

    for my $app ( $self->_psgi_apps() ) {
        printf(
            "    %50s ... [%s]\n",
            $app->name(),
            $app->is_running() ? 'running' : 'stopped'
        );
    }
}

sub _build_psgi_apps {
    my $self = shift;

    my @files
        = $self->_has_file()
        ? $self->file()
        : grep { ! $_->is_dir } $self->dir()->children();

    return [
        map { $self->_build_app_from_file($_) }
        grep {/\.conf/} grep {-s} @files
    ];
}

sub _build_app_from_file {
    my $self = shift;
    my $file = shift;

    my $cfg = Config::Any->load_files(
        {
            files           => [$file],
            flatten_to_hash => 1,
            use_ext         => 0,
        }
    );

    die "$file does not seem to contain any configuration\n"
        unless $cfg->{$file};

    $cfg = $cfg->{$file};

    die "$file does not contain a server key"
        unless defined $cfg->{server};

    my $app_class = first { try_load_class($_) } (
        'Emplacken::App::' . $cfg->{server},
        'Emplacken::App'
    );

    return $app_class->new( file => $file, %{$cfg} );
}

sub _maybe_print {
    my $self = shift;
    my $msg  = shift;

    return unless $self->verbose();

    print $msg;
}

1;

#ABSTRACT: Manage multiple plack apps with a directory of config files
