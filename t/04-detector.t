use strict;
use warnings;
use utf8;
use Test::More;
use Typo::Fossils::Detector qw(detect edit_distance);

binmode Test::More->builder->$_, ':encoding(UTF-8)'
    for qw(output failure_output todo_output);

is(edit_distance('teh', 'the'), 1, 'adjacent swap counts as one edit');
is(edit_distance('recieve', 'receive'), 1, 'swap inside a longer word');
is(edit_distance('kitten', 'sitting'), 3, 'plain levenshtein distance');
is(edit_distance('same', 'same'), 0, 'identical words');
is(edit_distance('abc', 'abd'), 1, 'single substitution');

my %counts = (
    the     => 120,
    teh     => 4,
    receive => 30,
    recieve => 2,
    cat     => 50,
    car     => 40,
    cut     => 45,
    separate => 25,
    seperate => 1,
    zebra   => 1,
    hello   => 20,
    helo    => 2,
    rare    => 3,
);

my @found = detect(\%counts, min_common => 5, max_typo => 3, min_ratio => 5);
my %by_typo = map { $_->{typo} => $_ } @found;

ok($by_typo{recieve}, 'finds a transposed word');
is($by_typo{recieve}{correction}, 'receive', 'with the right correction');
ok($by_typo{seperate}, 'finds a substituted letter');
is($by_typo{seperate}{correction}, 'separate', 'and corrects it');
ok($by_typo{helo}, 'finds a dropped letter');
is($by_typo{helo}{correction}, 'hello', 'and corrects it');
ok(!$by_typo{teh}, 'ignores words seen more often than max_typo');
ok(!$by_typo{zebra}, 'ignores rare words with no near neighbour');
ok(!$by_typo{car}, 'ignores common words');

my @loose = detect(\%counts, min_common => 5, max_typo => 4, min_ratio => 5);
my ($teh) = grep { $_->{typo} eq 'teh' } @loose;
ok($teh, 'raising max_typo includes it');
is($teh->{correction}, 'the', 'teh maps to the');
is($teh->{distance}, 1, 'with transposition distance 1');

my @strict = detect(\%counts, min_common => 5, max_typo => 3, min_ratio => 20);
ok(!(grep { $_->{typo} eq 'recieve' } @strict), 'min_ratio filters weak dominance');

my @none = detect(\%counts, min_common => 500);
is(scalar @none, 0, 'min_common filters everything when too high');

my @short = detect({ cat => 1, cut => 50, dog => 1, bat => 50 }, min_common => 5, max_typo => 3, min_ratio => 5);
is(scalar(grep { $_->{typo} eq 'cat' } @short), 1, 'short words allow one edit');

my @far = detect({ cat => 1, dot => 50 }, min_common => 5, max_typo => 3, min_ratio => 5);
is(scalar @far, 0, 'short words reject two edits');

my @tie = detect({ tset => 1, test => 50, text => 50 }, min_common => 5, max_typo => 3, min_ratio => 5);
is($tie[0]{correction}, 'test', 'ties break alphabetically');

my @ordered = detect(
    { receive => 100, recieve => 1, separate => 10, seperate => 3 },
    min_common => 5, max_typo => 3, min_ratio => 3,
);
is_deeply([ map { $_->{typo} } @ordered ], [qw(recieve seperate)], 'sorted by confidence');
cmp_ok($ordered[0]{confidence}, '>', $ordered[1]{confidence}, 'confidence decreases down the list');
like($ordered[0]{confidence}, qr/^\d\.\d{3}$/, 'confidence has three decimals');

is_deeply([ detect({}) ], [], 'empty table');

done_testing;