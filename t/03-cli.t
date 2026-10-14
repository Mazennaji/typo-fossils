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

done_testing;