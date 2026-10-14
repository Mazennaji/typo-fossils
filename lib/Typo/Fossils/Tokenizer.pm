package Typo::Fossils::Tokenizer;

use strict;
use warnings;
use utf8;
use feature 'fc';
use Exporter 'import';
use Unicode::Normalize qw(NFC);

our @EXPORT_OK = qw(tokenize);

sub tokenize {
    my ($text) = @_;
    return () unless defined $text && length $text;

    $text = NFC($text);
    $text =~ s{\bhttps?://\S+}{ }gi;
    $text =~ s{\S+@\S+}{ }g;

    my @words;
    while ($text =~ /([\p{L}\p{M}]+(?:['\x{2019}][\p{L}\p{M}]+)*)/g) {
        my $word = fc $1;
        $word =~ s/\x{2019}/'/g;
        push @words, $word if length($word) >= 2;
    }
    return @words;
}

1;