use strict;
use warnings;
use utf8;
use Test::More;
use Typo::Fossils::Stats qw(
    typo_total rate trend headline describe hall_of_fame retired
    format_change commify report
);

sub snap {
    my ($date, $words, %typos) = @_;
    return {
        date  => $date,
        words => $words,
        typos => { map { $_ => +{ fix => $typos{$_}[0], count => $typos{$_}[1] } } keys %typos },
    };
}

my $s1 = snap('2026-09-01', 1000, recieve => [ 'receive', 4 ], teh => [ 'the', 3 ]);
my $s2 = snap('2026-09-15', 2000, recieve => [ 'receive', 2 ], teh => [ 'the', 4 ]);
my $s3 = snap('2026-10-01', 1000, teh => [ 'the', 1 ]);

is(typo_total($s1), 7, 'adds up the typos in a snapshot');
is(typo_total(snap('2026-01-01', 10)), 0, 'a snapshot without typos totals zero');
is(rate($s1), 7, 'rate is typos per 1,000 words');
is(rate($s2), 3, 'rate scales with the word count');
is(rate({ words => 0, typos => {} }), 0, 'rate is zero when there are no words');

is(commify(0), '0', 'commify leaves zero alone');
is(commify(999), '999', 'commify leaves small numbers alone');
is(commify(1000), '1,000', 'commify adds one separator');
is(commify(1234567), '1,234,567', 'commify adds several separators');

is(format_change(undef), '-', 'no change is a dash');
is(format_change(0), '0%', 'zero change');
is(format_change(-29.4), '-29%', 'a drop');
is(format_change(12.6), '+13%', 'a rise');
is(format_change(-0.3), '0%', 'tiny changes round to zero');
is(format_change(-100), '-100%', 'a complete drop');

my @rows = trend($s1, $s2, $s3);
is(scalar @rows, 3, 'one trend row per snapshot');
is_deeply([ map { $_->{date} } @rows ], [qw(2026-09-01 2026-09-15 2026-10-01)], 'rows are in date order');
is_deeply([ map { $_->{typos} } @rows ], [ 7, 6, 1 ], 'rows carry the typo totals');
is_deeply([ map { $_->{words} } @rows ], [ 1000, 2000, 1000 ], 'and the word counts');
is($rows[0]{change}, undef, 'the first row has no change');
cmp_ok(abs($rows[1]{change} + 57.142857), '<', 0.001, 'later rows compare with the one before');
cmp_ok(abs($rows[2]{change} + 66.666667), '<', 0.001, 'and keep comparing');
is_deeply([ map { $_->{date} } trend($s3, $s1, $s2) ], [qw(2026-09-01 2026-09-15 2026-10-01)], 'unsorted input is sorted');

my @from_zero = trend(snap('2026-01-01', 100), snap('2026-02-01', 100, teh => [ 'the', 1 ]));
is($from_zero[1]{change}, undef, 'a change from zero is undefined');

is(headline($s1), undef, 'one snapshot has no headline');
is(headline(), undef, 'no snapshots have no headline');
my $overall = headline($s1, $s2, $s3);
is($overall->{from_date}, '2026-09-01', 'headline starts at the first snapshot');
is($overall->{to_date}, '2026-10-01', 'and ends at the last');
is($overall->{from_rate}, 7, 'with the first rate');
is($overall->{to_rate}, 1, 'and the last rate');
cmp_ok(abs($overall->{change} + 85.714286), '<', 0.001, 'and the overall change');

is(describe($overall), 'Down 86% since 2026-09-01 (7.0 to 1.0 per 1,000 words).', 'describes a drop');
is(
    describe({ from_date => '2026-01-01', to_date => '2026-02-01', from_rate => 1, to_rate => 2, change => 100 }),
    'Up 100% since 2026-01-01 (1.0 to 2.0 per 1,000 words).',
    'describes a rise'
);
is(
    describe({ from_date => '2026-01-01', to_date => '2026-02-01', from_rate => 3, to_rate => 3, change => 0 }),
    'Holding steady at 3.0 per 1,000 words since 2026-01-01.',
    'describes no change'
);
is(
    describe({ from_date => '2026-01-01', to_date => '2026-02-01', from_rate => 3, to_rate => 3.01, change => 0.33 }),
    'Holding steady at 3.0 per 1,000 words since 2026-01-01.',
    'tiny changes count as steady'
);
is(
    describe({ from_date => '2026-01-01', to_date => '2026-02-01', from_rate => 0, to_rate => 2, change => undef }),
    'Up from 0.0 to 2.0 per 1,000 words since 2026-01-01.',
    'describes a rise from zero'
);
is(
    describe({ from_date => '2026-01-01', to_date => '2026-02-01', from_rate => 0, to_rate => 0, change => undef }),
    'No tracked typos in either snapshot.',
    'describes two clean snapshots'
);

my @fame = hall_of_fame([ $s1, $s2, $s3 ]);
is_deeply([ map { $_->{typo} } @fame ], [qw(teh recieve)], 'hall of fame is ranked by total');
is_deeply([ map { $_->{total} } @fame ], [ 8, 6 ], 'with cumulative totals');
is_deeply([ map { $_->{snapshots} } @fame ], [ 3, 2 ], 'and the number of snapshots each appears in');
is_deeply([ map { $_->{last_seen} } @fame ], [qw(2026-10-01 2026-09-15)], 'and when each was last seen');
is_deeply([ map { $_->{fix} } @fame ], [qw(the receive)], 'and the correction');
is(scalar(hall_of_fame([ $s1, $s2, $s3 ], limit => 1)), 1, 'limit caps the list');
is_deeply(
    [ map { $_->{typo} } hall_of_fame([ snap('2026-01-01', 10, aaa => [ 'x', 2 ], bbb => [ 'y', 2 ]) ]) ],
    [qw(aaa bbb)],
    'ties break alphabetically'
);
is_deeply([ hall_of_fame([ snap('2026-01-01', 10, zero => [ 'x', 0 ]) ]) ], [], 'zero counts are ignored');
is_deeply([ hall_of_fame([]) ], [], 'no snapshots, no hall of fame');

my @gone = retired([ $s1, $s2, $s3 ]);
is_deeply([ map { $_->{typo} } @gone ], ['recieve'], 'a typo missing from the latest snapshot is retired');
is($gone[0]{total}, 6, 'with its earlier total');
is($gone[0]{fix}, 'receive', 'and its correction');
is_deeply([ retired([ $s1 ]) ], [], 'one snapshot has nothing retired');
is_deeply([ retired([ $s2, $s1 ]) ], [], 'a typo still present is not retired, whatever the input order');
is_deeply([ retired([ snap('2026-01-01', 10, a => [ 'x', 1 ]), snap('2026-02-01', 10, a => [ 'x', 0 ]) ]) ], [ { typo => 'a', fix => 'x', total => 1 } ], 'a zero count in the latest snapshot counts as retired');

is(report([]), "No history yet. Run typo-fossils track PATH first.\n", 'report explains how to start');

my $text = report([ $s1, $s2, $s3 ]);
like($text, qr/^Snapshots: 3 \(2026-09-01 to 2026-10-01\)$/m, 'report counts the snapshots');
like($text, qr/^Words tracked: 4,000$/m, 'and the words');
like($text, qr/^Typos found: 14$/m, 'and the typos');
like($text, qr/^DATE\s+WORDS\s+TYPOS\s+RATE\s+CHANGE$/m, 'report has a trend header');
like($text, qr/^2026-09-01\s+1,000\s+7\s+7\.0\s+-$/m, 'the first row has no change');
like($text, qr/^2026-09-15\s+2,000\s+6\s+3\.0\s+-57%$/m, 'later rows show the change');
like($text, qr/^2026-10-01\s+1,000\s+1\s+1\.0\s+-67%$/m, 'and keep showing it');
like($text, qr/^Down 86% since 2026-09-01 \(7\.0 to 1\.0 per 1,000 words\)\.$/m, 'report has the headline');
like($text, qr/^Hall of fame$/m, 'report has a hall of fame');
like($text, qr/^1\s+teh\s+the\s+8\s+3\s+2026-10-01$/m, 'ranked first');
like($text, qr/^2\s+recieve\s+receive\s+6\s+2\s+2026-09-15$/m, 'ranked second');
like($text, qr/^Retired \(not in your latest snapshot\): recieve \(6\)$/m, 'report lists retired typos');

my $short = report([ $s1, $s2, $s3 ], top => 1);
like($short, qr/^1\s+teh\s+the/m, 'top keeps the first entry');
unlike($short, qr/^2\s+recieve/m, 'and drops the rest');

my $many = report([
    snap('2026-01-01', 100, aaa => [ 'a1', 3 ], bbb => [ 'b1', 2 ], ccc => [ 'c1', 1 ]),
    snap('2026-02-01', 100),
], top => 1);
like($many, qr/^Retired \(not in your latest snapshot\): aaa \(3\) and 2 more$/m, 'a long retired list is shortened');

my $single = report([ $s1 ]);
like($single, qr/^Snapshots: 1 \(2026-09-01\)$/m, 'a single snapshot shows one date');
like($single, qr/^Track again after more writing to see a trend\.$/m, 'and suggests tracking again');
unlike($single, qr/Retired/, 'and has nothing retired');

my $clean = report([ snap('2026-01-01', 100) ]);
like($clean, qr/^No tracked typos in any snapshot yet\.$/m, 'a clean history says so');

done_testing;