package Typo::Fossils::Store;

use strict;
use warnings;
use utf8;
use JSON::PP ();
use File::Basename qw(dirname);
use File::Path qw(make_path);

sub default_path {
    my $base = $ENV{XDG_CONFIG_HOME} || (($ENV{HOME} // '.') . '/.config');
    return "$base/typo-fossils/decisions.json";
}

sub new {
    my ($class, $path) = @_;
    $path //= default_path();
    my $self = bless { path => $path, accepted => {}, rejected => {} }, $class;
    $self->_load if -e $path;
    return $self;
}

sub path { return $_[0]{path} }

sub _load {
    my ($self) = @_;
    open my $fh, '<:raw', $self->{path} or die "Cannot read $self->{path}: $!\n";
    local $/;
    my $json = <$fh>;
    close $fh;

    return unless defined $json && $json =~ /\S/;

    my $data = eval { JSON::PP->new->utf8->decode($json) };
    die "Invalid store file: $self->{path}\n" unless ref $data eq 'HASH';

    $self->{accepted} = $data->{accepted} // {};
    $self->{rejected} = $data->{rejected} // {};
}

sub save {
    my ($self) = @_;
    my $dir = dirname($self->{path});
    make_path($dir) unless -d $dir;

    my $tmp = "$self->{path}.tmp";
    open my $fh, '>:raw', $tmp or die "Cannot write $tmp: $!\n";
    print {$fh} JSON::PP->new->utf8->canonical->pretty->encode({
        accepted => $self->{accepted},
        rejected => $self->{rejected},
    });
    close $fh or die "Cannot write $tmp: $!\n";
    rename $tmp, $self->{path} or die "Cannot replace $self->{path}: $!\n";
}

sub accept {
    my ($self, $typo, $fix) = @_;
    $self->{accepted}{$typo} = $fix;
    delete $self->{rejected}{$typo};
}

sub reject {
    my ($self, $typo, $fix) = @_;
    $self->{rejected}{$typo} = $fix;
    delete $self->{accepted}{$typo};
}

sub is_decided {
    my ($self, $typo, $fix) = @_;
    return 1 if exists $self->{accepted}{$typo};
    return 1 if exists $self->{rejected}{$typo} && $self->{rejected}{$typo} eq $fix;
    return 0;
}

sub accepted { return %{ $_[0]{accepted} } }

1;