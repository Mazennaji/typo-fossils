use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use FindBin qw($Bin);

my $script = File::Spec->catfile($Bin, '..', 'bin', 'typo-fossils');
my $dir    = tempdir(CLEANUP => 1);
my $file   = File::Spec->catfile($dir, 'notes.txt');

open my $fh, '>', $file or die $!;
print {$fh} "the the the cat cat dog";
close $fh;

my $out = qx{$^X $script freq --top 2 $file};
is($? >> 8, 0, 'freq exits cleanly');
like($out, qr/^\s+3\s+the$/m, 'lists the most frequent word');
like($out, qr/^\s+2\s+cat$/m, 'lists the second word');
unlike($out, qr/dog/, 'respects --top');

my $filtered = qx{$^X $script freq --min-count 2 $file};
unlike($filtered, qr/dog/, 'respects --min-count');

my $version = qx{$^X $script --version};
like($version, qr/^typo-fossils \d+\.\d+/, 'prints version');

my $typos = File::Spec->catfile($dir, 'typos.txt');
open my $tfh, '>', $typos or die $!;
print {$tfh} join(' ', ('receive') x 10), " recieve\n";
close $tfh;

my $scan = qx{$^X $script scan $typos};
is($? >> 8, 0, 'scan exits cleanly');
like($scan, qr/recieve\s+receive/, 'scan finds the typo');

my $store = File::Spec->catfile($dir, 'decisions.json');
my $answers = File::Spec->catfile($dir, 'answers.txt');
open my $afh, '>', $answers or die $!;
print {$afh} "a\n";
close $afh;

my $review = qx{$^X $script review --store $store $typos < $answers};
is($? >> 8, 0, 'review exits cleanly');
like($review, qr/recieve -> receive/, 'review shows the candidate');
like($review, qr/Accepted 1, rejected 0, skipped 0, left 0\./, 'review prints a summary');
ok(-f $store, 'review writes the decisions file');

my $list = qx{$^X $script list --store $store};
like($list, qr/recieve\s+-> receive/, 'list shows the accepted pair');

my $again = qx{$^X $script review --store $store $typos < $answers};
like($again, qr/Nothing to review\./, 'a decided candidate is not offered again');

my $missing = File::Spec->catfile($dir, 'missing.json');
my $none = qx{$^X $script list --store $missing};
like($none, qr/No accepted typos yet\./, 'list handles a missing store');

done_testing;