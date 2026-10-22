use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use Typo::Fossils::History qw(parse_date today);

binmode Test::More->builder->$_, ':encoding(UTF-8)'
    for qw(output failure_output todo_output);

sub write_file {
    my ($path, $text) = @_;
    open my $fh, '>:raw', $path or die "Cannot write $path: $!";
    print {$fh} $text;
    close $fh;
}

my $dir  = tempdir(CLEANUP => 1);
my $path = File::Spec->catfile($dir, 'nested', 'deeper', 'history.json');

my $history = Typo::Fossils::History->new($path);
is_deeply([ $history->snapshots ], [], 'starts empty when the file does not exist');
is($history->path, $path, 'reports its path');
ok(!$history->has_date('2026-10-01'), 'no dates at first');

$history->record(date => '2026-10-15', words => 2000, typos => { teh => { fix => 'the', count => 4 } });
$history->record(date => '2026-10-01', words => 1000, typos => { recieve => { fix => 'receive', count => 2 } });
is_deeply([ map { $_->{date} } $history->snapshots ], [qw(2026-10-01 2026-10-15)], 'snapshots are kept in date order');
ok($history->has_date('2026-10-01'), 'has_date finds a recorded date');
ok(!$history->has_date('2026-10-02'), 'and not others');

$history->record(date => '2026-10-01', words => 1500, typos => {});
is(scalar($history->snapshots), 2, 'recording the same date replaces the snapshot');
my ($first) = $history->snapshots;
is($first->{words}, 1500, 'with the new word count');
is_deeply($first->{typos}, {}, 'and the new typos');

$history->save;
ok(-f $path, 'save creates missing directories and the file');
ok(!-e "$path.tmp", 'and leaves no temp file');

my $reloaded = Typo::Fossils::History->new($path);
is_deeply([ $reloaded->snapshots ], [ $history->snapshots ], 'snapshots survive a reload');

$reloaded->record(date => '2026-11-01', words => 10, typos => { caffe => { fix => "caf\x{e9}", count => 1 } });
$reloaded->save;
my ($last) = reverse(Typo::Fossils::History->new($path)->snapshots);
is($last->{typos}{caffe}{fix}, "caf\x{e9}", 'unicode corrections round trip');

my $scratch = File::Spec->catfile($dir, 'scratch.json');
my @bad_records = (
    [ 'a bad date format',  date => '2026-1-1',   words => 1,      typos => {} ],
    [ 'a missing date',                            words => 1,      typos => {} ],
    [ 'a bad word count',   date => '2026-10-01', words => 'many', typos => {} ],
    [ 'missing typos',      date => '2026-10-01', words => 1 ],
    [ 'a bad typo entry',   date => '2026-10-01', words => 1,      typos => { teh => 'the' } ],
    [ 'a negative count',   date => '2026-10-01', words => 1,      typos => { teh => { fix => 'the', count => -1 } } ],
    [ 'a missing fix',      date => '2026-10-01', words => 1,      typos => { teh => { count => 1 } } ],
);
for my $bad (@bad_records) {
    my ($label, @args) = @$bad;
    eval { Typo::Fossils::History->new($scratch)->record(@args) };
    like($@, qr/Invalid snapshot/, "record rejects $label");
}

my $empty = File::Spec->catfile($dir, 'empty.json');
write_file($empty, '');
is_deeply([ Typo::Fossils::History->new($empty)->snapshots ], [], 'an empty file is a fresh history');

my %broken = (
    'invalid json'                     => '{ not json',
    'a top-level list'                 => '[1, 2, 3]',
    'a missing snapshots key'          => '{"other": []}',
    'snapshots that are not a list'    => '{"snapshots": {}}',
    'a snapshot without a date'        => '{"snapshots": [{"words": 1, "typos": {}}]}',
    'a snapshot with a bad date'       => '{"snapshots": [{"date": "yesterday", "words": 1, "typos": {}}]}',
    'a snapshot with a bad typo entry' => '{"snapshots": [{"date": "2026-10-01", "words": 1, "typos": {"teh": 3}}]}',
);
for my $name (sort keys %broken) {
    my $file = File::Spec->catfile($dir, 'broken.json');
    write_file($file, $broken{$name});
    eval { Typo::Fossils::History->new($file) };
    like($@, qr/Invalid history file/, "rejects $name");
}

{
    local $ENV{XDG_CONFIG_HOME} = '/custom/config';
    is(Typo::Fossils::History::default_path(), '/custom/config/typo-fossils/history.json', 'default path honours XDG_CONFIG_HOME');
}

ok(defined parse_date('2026-10-22'), 'parses a valid date');
my @parts = localtime parse_date('2026-10-22');
is(join('-', $parts[5] + 1900, $parts[4] + 1, $parts[3]), '2026-10-22', 'to the start of that local day');
ok(parse_date('2026-10-23') > parse_date('2026-10-22'), 'later dates give later times');
ok(defined parse_date('2028-02-29'), 'accepts a leap day');

for my $bad ('2026-02-30', '2027-02-29', '2026-13-01', '2026-00-10', '2026-10-00', '2026-10-32', '2026-1-5', 'yesterday', '', "2026-10-22\n", '2026-10-22 ') {
    my $label = $bad =~ s/\n/\\n/r;
    is(parse_date($bad), undef, "rejects '$label'");
}
is(parse_date(undef), undef, 'rejects undef');

like(today(), qr/\A\d{4}-\d{2}-\d{2}\z/, 'today is formatted as a date');
ok(defined parse_date(today()), 'and is a valid date');

done_testing;