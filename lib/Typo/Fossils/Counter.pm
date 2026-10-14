package Typo::Fossils::Counter;

use strict;
use warnings;
use utf8;
use Exporter 'import';
use Typo::Fossils::Tokenizer qw(tokenize);
use Typo::Fossils::Reader qw(find_files read_file);

our @EXPORT_OK = qw(count_words count_paths top_words);

sub count_words {
    my ($text, $counts) = @_;
    $counts //= {};
    $counts->{$_}++ for tokenize($text);
    return $counts;
}

sub count_paths {
    my (@paths) = @_;
    my $counts = {};
    count_words(read_file($_), $counts) for find_files(@paths);
    return $counts;
}

sub top_words {
    my ($counts, %opt) = @_;
    my $min   = $opt{min_count} // 1;
    my $limit = $opt{limit};

    my @words = sort { $counts->{$b} <=> $counts->{$a} || $a cmp $b }
                grep { $counts->{$_} >= $min } keys %$counts;

    splice @words, $limit if defined $limit && $limit < @words;
    return map { [ $_, $counts->{$_} ] } @words;
}

1;