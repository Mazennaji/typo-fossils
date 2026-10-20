use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use FindBin qw($Bin);

my $script = File::Spec->catfile($Bin, '..', 'bin', 'typo-fossils');
my $dir    = tempdir(CLEANUP => 1);
my $file   = File::Spec->catfile($dir, 'notes.txt');

sub slurp {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "Cannot read $path: $!";
    local $/;
    my $bytes = <$fh>;
    close $fh;
    return $bytes;
}

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

my $yml = File::Spec->catfile($dir, 'typos.yml');
my $exported = qx{$^X $script export --store $store --out $yml};
is($? >> 8, 0, 'export exits cleanly');
like($exported, qr/^Wrote 1 typo to .*typos\.yml \(espanso\)\.$/m, 'export infers espanso from the file name');
like(slurp($yml), qr/trigger: "recieve"\n\s+replace: "receive"/, 'export writes the espanso file');

my $vim = qx{$^X $script export --store $store --format vim};
is($? >> 8, 0, 'export to stdout exits cleanly');
is($vim, "iabbrev recieve receive\n", 'export prints only the vim lines to stdout');

my $plist = qx{$^X $script export --store $store --format MACOS};
like($plist, qr{<key>shortcut</key>\s*<string>recieve</string>}, 'export accepts the macos format in any case');

my $no_format = qx{$^X $script export --store $store 2>&1};
isnt($? >> 8, 0, 'export without a format fails');
like($no_format, qr/Choose a format with --format/, 'and explains what to do');

my $bad_format = qx{$^X $script export --store $store --format docx 2>&1};
isnt($? >> 8, 0, 'an unknown format fails');
like($bad_format, qr/Unknown format 'docx'/, 'and names it');

my $empty = qx{$^X $script export --store $missing --format vim 2>&1};
is($? >> 8, 1, 'export with nothing accepted exits with status 1');
like($empty, qr/No accepted typos yet\. Run typo-fossils review first\./, 'and says why');
ok(!-e File::Spec->catfile($dir, 'never.vim'), 'no file is written');

my $mixed = File::Spec->catfile($dir, 'mixed.json');
open my $mfh, '>', $mixed or die $!;
print {$mfh} qq({"accepted":{"teh":"the","wouldn't":"would not"},"rejected":{}});
close $mfh;

my $skipped = qx{$^X $script export --store $mixed --format vim 2>&1};
is($? >> 8, 0, 'export succeeds when only some entries are skipped');
like($skipped, qr/Skipped 1 entry the vim format cannot hold: wouldn't/, 'export reports skipped entries');
like($skipped, qr/^iabbrev teh the$/m, 'and still exports the rest');

done_testing;