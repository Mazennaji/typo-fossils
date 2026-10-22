use strict;
use warnings;
use Test::More;
use File::Spec;
use FindBin qw($Bin);

my @modules = qw(
    Typo::Fossils
    Typo::Fossils::Counter
    Typo::Fossils::Detector
    Typo::Fossils::Exporter
    Typo::Fossils::History
    Typo::Fossils::Keyboard
    Typo::Fossils::Reader
    Typo::Fossils::Review
    Typo::Fossils::Stats
    Typo::Fossils::Store
    Typo::Fossils::Tokenizer
);

use_ok($_) for @modules;

like(Typo::Fossils->version, qr/\A\d+\.\d+/, 'the version looks like a version');

my $script = File::Spec->catfile($Bin, '..', 'bin', 'typo-fossils');
my $check  = qx{$^X -c $script 2>&1};
is($? >> 8, 0, 'the command line script compiles');
like($check, qr/syntax OK/, 'and reports its syntax as fine');

done_testing;