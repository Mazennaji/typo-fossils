package Typo::Fossils::History;

use strict;
use warnings;
use utf8;
use Exporter 'import';
use JSON::PP ();
use File::Basename qw(dirname);
use File::Path qw(make_path);
use POSIX ();
use Time::Local qw(timelocal);

our @EXPORT_OK = qw(parse_date today);

sub default_path {
    my $base = $ENV{XDG_CONFIG_HOME} || (($ENV{HOME} // '.') . '/.config');
    return "$base/typo-fossils/history.json";
}

sub today {
    return POSIX::strftime('%Y-%m-%d', localtime);
}

sub parse_date {
    my ($text) = @_;
    return undef unless defined $text && $text =~ /\A(\d{4})-(\d{2})-(\d{2})\z/;

    my ($year, $month, $day) = ($1, $2, $3);
    my $epoch = eval { timelocal(0, 0, 0, $day, $month - 1, $year) };
    return undef unless defined $epoch;

    my @back = localtime $epoch;
    return undef unless $back[5] + 1900 == $year && $back[4] + 1 == $month && $back[3] == $day;
    return $epoch;
}

sub valid_snapshot {
    my ($snapshot) = @_;
    return 0 unless ref $snapshot eq 'HASH';
    return 0 unless defined $snapshot->{date} && $snapshot->{date} =~ /\A\d{4}-\d{2}-\d{2}\z/;
    return 0 unless defined $snapshot->{words} && $snapshot->{words} =~ /\A\d+\z/;
    return 0 unless ref $snapshot->{typos} eq 'HASH';

    for my $entry (values %{ $snapshot->{typos} }) {
        return 0 unless ref $entry eq 'HASH';
        return 0 unless defined $entry->{fix} && !ref $entry->{fix};
        return 0 unless defined $entry->{count} && $entry->{count} =~ /\A\d+\z/;
    }
    return 1;
}

sub new {
    my ($class, $path) = @_;
    $path //= default_path();
    my $self = bless { path => $path, snapshots => [] }, $class;
    $self->_load if -e $path;
    return $self;
}

sub path { return $_[0]{path} }

sub snapshots { return @{ $_[0]{snapshots} } }

sub has_date {
    my ($self, $date) = @_;
    return scalar grep { $_->{date} eq $date } @{ $self->{snapshots} };
}

sub _load {
    my ($self) = @_;
    open my $fh, '<:raw', $self->{path} or die "Cannot read $self->{path}: $!\n";
    local $/;
    my $json = <$fh>;
    close $fh;

    return unless defined $json && $json =~ /\S/;

    my $data = eval { JSON::PP->new->utf8->decode($json) };
    die "Invalid history file: $self->{path}\n"
        unless ref $data eq 'HASH'
            && ref $data->{snapshots} eq 'ARRAY'
            && !grep { !valid_snapshot($_) } @{ $data->{snapshots} };

    $self->{snapshots} = [ sort { $a->{date} cmp $b->{date} } @{ $data->{snapshots} } ];
}

sub record {
    my ($self, %snapshot) = @_;
    my $entry = {
        date  => $snapshot{date},
        words => $snapshot{words},
        typos => $snapshot{typos},
    };
    die "Invalid snapshot\n" unless valid_snapshot($entry);

    $self->{snapshots} = [
        sort { $a->{date} cmp $b->{date} }
        (grep { $_->{date} ne $entry->{date} } @{ $self->{snapshots} }), $entry
    ];
    return $entry;
}

sub save {
    my ($self) = @_;
    my $dir = dirname($self->{path});
    make_path($dir) unless -d $dir;

    my $tmp = "$self->{path}.tmp";
    open my $fh, '>:raw', $tmp or die "Cannot write $tmp: $!\n";
    print {$fh} JSON::PP->new->utf8->canonical->pretty->encode({ snapshots => $self->{snapshots} });
    close $fh or die "Cannot write $tmp: $!\n";
    rename $tmp, $self->{path} or die "Cannot replace $self->{path}: $!\n";
}

1;