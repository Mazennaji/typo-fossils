package Typo::Fossils::Detector;

use strict;
use warnings;
use utf8;
use Exporter 'import';
use List::Util qw(max min);
use Text::Levenshtein qw(distance);
use Typo::Fossils::Keyboard qw(classify swap_index);

our @EXPORT_OK = qw(detect edit_distance);

sub edit_distance {
    my ($x, $y) = @_;
    my $d = distance($x, $y);
    return $d if $d <= 1;
    return 1 if swap_index($x, $y) >= 0;
    return $d;
}

sub detect {
    my ($counts, %opt) = @_;
    my $max_distance = $opt{max_distance} // 2;
    my $min_common   = $opt{min_common}   // 5;
    my $max_typo     = $opt{max_typo}     // 3;
    my $min_ratio    = $opt{min_ratio}    // 5;
    my $min_length   = $opt{min_length}   // 3;
    my $layout       = $opt{layout}       // 'qwerty';

    my %by_length;
    for my $word (keys %$counts) {
        next if $counts->{$word} < $min_common;
        push @{ $by_length{ length $word } }, $word;
    }

    my @found;
    for my $typo (keys %$counts) {
        my $typo_count = $counts->{$typo};
        next if $typo_count > $max_typo || length($typo) < $min_length;

        my $limit = length($typo) <= 4 ? min(1, $max_distance) : $max_distance;
        my @matches;

        for my $len (length($typo) - $limit .. length($typo) + $limit) {
            for my $candidate (@{ $by_length{$len} // [] }) {
                next if $candidate eq $typo;

                my $candidate_count = $counts->{$candidate};
                next if $candidate_count < $min_ratio * $typo_count;

                my $d = edit_distance($typo, $candidate);
                next if $d > $limit;

                push @matches, {
                    typo             => $typo,
                    correction       => $candidate,
                    distance         => $d,
                    typo_count       => $typo_count,
                    correction_count => $candidate_count,
                };
            }
        }

        next unless @matches;

        my ($best) = sort {
            $a->{distance} <=> $b->{distance}
            || $b->{correction_count} <=> $a->{correction_count}
            || $a->{correction} cmp $b->{correction}
        } @matches;

        my $similarity = 1 - $best->{distance} / max(length($typo), length($best->{correction}));
        my $dominance  = $best->{correction_count} / ($best->{correction_count} + $typo_count);
        $best->{confidence} = sprintf('%.3f', $similarity * $dominance);
        @{$best}{qw(kind reason)} = classify($typo, $best->{correction}, $layout);

        push @found, $best;
    }

    return sort {
        $b->{confidence} <=> $a->{confidence}
        || $b->{typo_count} <=> $a->{typo_count}
        || $a->{typo} cmp $b->{typo}
    } @found;
}

1;