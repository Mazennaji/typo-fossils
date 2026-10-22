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
like($scan, qr/KIND/, 'scan prints a kind column');
like($scan, qr/gap \(ie\/ei swap\)/, 'scan labels the typo');

my $gaps = qx{$^X $script scan --kind gap $typos};
like($gaps, qr/recieve/, 'scan --kind gap keeps gaps');

my $slips = qx{$^X $script scan --kind slip $typos};
like($slips, qr/No typo candidates found\./, 'scan --kind slip hides gaps');

my $bad_kind = qx{$^X $script scan --kind bogus $typos 2>&1};
isnt($? >> 8, 0, 'an unknown kind fails');
like($bad_kind, qr/Unknown kind 'bogus'\. Choose slip, gap, unclear, or all\./, 'and explains the choices');

my $bad_layout = qx{$^X $script scan --layout dvorak $typos 2>&1};
isnt($? >> 8, 0, 'an unknown layout fails');
like($bad_layout, qr/Unknown layout 'dvorak'\. Choose one of: azerty, qwerty, qwertz/, 'and lists the layouts');

my $azerty = qx{$^X $script scan --layout AZERTY $typos};
is($? >> 8, 0, 'a layout name works in any case');

my $store = File::Spec->catfile($dir, 'decisions.json');
my $answers = File::Spec->catfile($dir, 'answers.txt');
open my $afh, '>', $answers or die $!;
print {$afh} "a\n";
close $afh;

my $review = qx{$^X $script review --store $store $typos < $answers};
is($? >> 8, 0, 'review exits cleanly');
like($review, qr/recieve -> receive/, 'review shows the candidate');
like($review, qr/confidence \d\.\d{3}, gap \(ie\/ei swap\)/, 'review shows the kind');
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

my $history = File::Spec->catfile($dir, 'history.json');

my $no_history = qx{$^X $script stats --history $history};
is($? >> 8, 0, 'stats exits cleanly without a history');
like($no_history, qr/No history yet\. Run typo-fossils track PATH first\./, 'and says how to start');

my $tracked = qx{$^X $script track --store $store --history $history --date 2026-10-01 $typos};
is($? >> 8, 0, 'track exits cleanly');
like($tracked, qr/^Recorded 2026-10-01: 11 words, 1 typo \(90\.9 per 1,000 words\)\.$/m, 'track reports the snapshot');
ok(-f $history, 'track writes the history file');

my $retracked = qx{$^X $script track --store $store --history $history --date 2026-10-01 $typos};
like($retracked, qr/^Updated 2026-10-01: 11 words, 1 typo/m, 'tracking the same date again updates it');

my $recent = qx{$^X $script track --store $store --history $history --date 2026-10-02 --since 2000-01-01 $typos};
is($? >> 8, 0, 'track accepts --since');
like($recent, qr/^Recorded 2026-10-02: 11 words/m, 'and includes files modified since then');

my $clean = File::Spec->catfile($dir, 'clean.txt');
open my $cfh, '>', $clean or die $!;
print {$cfh} join(' ', ('receive') x 20), "\n";
close $cfh;

my $improved = qx{$^X $script track --store $store --history $history --date 2026-10-15 $clean};
like($improved, qr/^Recorded 2026-10-15: 20 words, 0 typos \(0\.0 per 1,000 words\)\.$/m, 'a clean snapshot has no typos');

my $stats = qx{$^X $script stats --history $history};
is($? >> 8, 0, 'stats exits cleanly');
like($stats, qr/^Snapshots: 3 \(2026-10-01 to 2026-10-15\)$/m, 'stats counts the snapshots');
like($stats, qr/^2026-10-15\s+20\s+0\s+0\.0\s+-100%$/m, 'stats shows the trend');
like($stats, qr/^Down 100% since 2026-10-01 \(90\.9 to 0\.0 per 1,000 words\)\.$/m, 'and the headline');
like($stats, qr/^1\s+recieve\s+receive\s+2\s+2\s+2026-10-02$/m, 'and the hall of fame');
like($stats, qr/^Retired \(not in your latest snapshot\): recieve \(2\)$/m, 'and the retired typos');

my $top_zero = qx{$^X $script stats --history $history --top 0 2>&1};
isnt($? >> 8, 0, 'stats rejects --top below 1');
like($top_zero, qr/--top must be at least 1\./, 'and says why');

my $bad_date = qx{$^X $script track --store $store --history $history --date 2026-02-30 $typos 2>&1};
isnt($? >> 8, 0, 'track rejects an invalid date');
like($bad_date, qr/Invalid date '2026-02-30'\. Use YYYY-MM-DD\./, 'and explains the format');

my $bad_since = qx{$^X $script track --store $store --history $history --since nope $typos 2>&1};
isnt($? >> 8, 0, 'track rejects an invalid --since');
like($bad_since, qr/Invalid date 'nope'\. Use YYYY-MM-DD\./, 'and explains the format');

my $nothing = qx{$^X $script track --store $store --history $history --since 2999-01-01 $typos 2>&1};
is($? >> 8, 1, 'track with no matching files exits with status 1');
like($nothing, qr/No words found\. Check the paths and --since\./, 'and says why');

my $no_pairs = qx{$^X $script track --store $missing --history $history $typos 2>&1};
is($? >> 8, 1, 'track with nothing accepted exits with status 1');
like($no_pairs, qr/No accepted typos yet\. Run typo-fossils review first\./, 'and says why');

done_testing;