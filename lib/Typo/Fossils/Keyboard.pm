package Typo::Fossils::Keyboard;

use strict;
use warnings;
use utf8;
use Exporter 'import';

our @EXPORT_OK = qw(classify is_adjacent swap_index supported_layouts);

my %LAYOUTS = (
    qwerty => [qw(qwertyuiop asdfghjkl zxcvbnm)],
    azerty => [qw(azertyuiop qsdfghjklm wxcvbn)],
    qwertz => [qw(qwertzuiop asdfghjkl yxcvbnm)],
);

my @ROW_OFFSETS = (0, 0.25, 0.75);
my $REACH       = 1.3;
my %POSITIONS;

sub supported_layouts { return sort keys %LAYOUTS }

sub positions {
    my ($layout) = @_;
    return $POSITIONS{$layout} //= do {
        my $rows = $LAYOUTS{$layout}
            or die sprintf("Unknown layout '%s'. Choose one of: %s\n", $layout, join(', ', supported_layouts()));
        my %pos;
        for my $y (0 .. $#$rows) {
            my @keys = split //, $rows->[$y];
            $pos{ $keys[$_] } = [ $_ + $ROW_OFFSETS[$y], $y ] for 0 .. $#keys;
        }
        \%pos;
    };
}

sub is_adjacent {
    my ($first, $second, $layout) = @_;
    my $pos = positions($layout // 'qwerty');
    my ($p, $q) = ($pos->{ lc $first }, $pos->{ lc $second });
    return 0 unless $p && $q;
    return 0 if lc $first eq lc $second;

    my ($dx, $dy) = ($p->[0] - $q->[0], $p->[1] - $q->[1]);
    return sqrt($dx * $dx + $dy * $dy) <= $REACH ? 1 : 0;
}

sub swap_index {
    my ($x, $y) = @_;
    return -1 if length($x) != length($y) || $x eq $y;

    my $i = 0;
    $i++ while substr($x, $i, 1) eq substr($y, $i, 1);

    return -1 if $i + 1 >= length($x);
    return -1 unless substr($x, $i, 1) eq substr($y, $i + 1, 1)
                  && substr($x, $i + 1, 1) eq substr($y, $i, 1);

    return substr($x, $i + 2) eq substr($y, $i + 2) ? $i : -1;
}

sub repeats_neighbour {
    my ($word, $i) = @_;
    my $letter = substr($word, $i, 1);
    return 1 if $i > 0 && substr($word, $i - 1, 1) eq $letter;
    return 1 if $i < length($word) - 1 && substr($word, $i + 1, 1) eq $letter;
    return 0;
}

sub touches_neighbour {
    my ($word, $i, $layout) = @_;
    my $letter = substr($word, $i, 1);
    return 1 if $i > 0 && is_adjacent($letter, substr($word, $i - 1, 1), $layout);
    return 1 if $i < length($word) - 1 && is_adjacent($letter, substr($word, $i + 1, 1), $layout);
    return 0;
}

sub classify {
    my ($typo, $fix, $layout) = @_;
    $layout //= 'qwerty';
    positions($layout);

    my $swap = swap_index($typo, $fix);
    if ($swap >= 0) {
        my $pair = join '', sort { $a cmp $b } split //, substr($typo, $swap, 2);
        return $pair eq 'ei' ? ('gap', 'ie/ei swap') : ('slip', 'swapped letters');
    }

    my ($typo_len, $fix_len) = (length $typo, length $fix);

    if ($typo_len == $fix_len) {
        my @diff = grep { substr($typo, $_, 1) ne substr($fix, $_, 1) } 0 .. $typo_len - 1;
        return ('unclear', 'several edits') unless @diff == 1;

        my ($got, $want) = (substr($typo, $diff[0], 1), substr($fix, $diff[0], 1));
        return ('slip', 'adjacent key') if is_adjacent($got, $want, $layout);
        return ('gap', 'vowel swap') if $got =~ /[aeiou]/ && $want =~ /[aeiou]/;
        return ('unclear', 'other substitution');
    }

    if ($typo_len == $fix_len - 1) {
        for my $i (0 .. $fix_len - 1) {
            next unless substr($fix, 0, $i) . substr($fix, $i + 1) eq $typo;
            return repeats_neighbour($fix, $i) ? ('gap', 'missing double letter') : ('slip', 'dropped letter');
        }
        return ('unclear', 'several edits');
    }

    if ($typo_len == $fix_len + 1) {
        for my $i (0 .. $typo_len - 1) {
            next unless substr($typo, 0, $i) . substr($typo, $i + 1) eq $fix;
            return ('gap', 'extra double letter') if repeats_neighbour($typo, $i);
            return touches_neighbour($typo, $i, $layout) ? ('slip', 'extra key') : ('unclear', 'extra letter');
        }
        return ('unclear', 'several edits');
    }

    return ('unclear', 'several edits');
}

1;