use strict;
use warnings;
use utf8;
use Test::More;
use Typo::Fossils::Keyboard qw(classify is_adjacent swap_index supported_layouts);

binmode Test::More->builder->$_, ':encoding(UTF-8)'
    for qw(output failure_output todo_output);

is_deeply([ supported_layouts() ], [qw(azerty qwerty qwertz)], 'lists the layouts');

ok(is_adjacent('q', 'w'), 'neighbours in a row');
ok(is_adjacent('g', 'h'), 'neighbours in the home row');
ok(is_adjacent('a', 'q'), 'a touches q');
ok(is_adjacent('a', 'w'), 'a touches w');
ok(is_adjacent('a', 'z'), 'a touches z');
ok(is_adjacent('s', 'x'), 's touches x');
ok(is_adjacent('e', 'd'), 'e touches d');
ok(is_adjacent('p', 'l'), 'p touches l');
ok(is_adjacent('m', 'k'), 'm touches k');
ok(is_adjacent('Q', 'W'), 'uppercase works');
ok(!is_adjacent('a', 'x'), 'a does not touch x');
ok(!is_adjacent('q', 's'), 'q does not touch s on qwerty');
ok(!is_adjacent('e', 'f'), 'e does not touch f');
ok(!is_adjacent('q', 'p'), 'opposite ends are far apart');
ok(!is_adjacent('a', 'a'), 'a key is not adjacent to itself');
ok(!is_adjacent("'", 'l'), 'punctuation is not on the map');
ok(!is_adjacent("\x{e9}", 'e'), 'accented letters are not on the map');
ok(is_adjacent('q', 's', 'azerty'), 'q touches s on azerty');
ok(is_adjacent('a', 'q', 'azerty'), 'a touches q on azerty');
ok(is_adjacent('z', 'u', 'qwertz'), 'z touches u on qwertz');
ok(!is_adjacent('z', 'u', 'qwerty'), 'z does not touch u on qwerty');
ok(is_adjacent('y', 'x', 'qwertz'), 'y touches x on qwertz');
ok(!is_adjacent('y', 'x', 'qwerty'), 'y does not touch x on qwerty');

eval { is_adjacent('a', 's', 'dvorak') };
like($@, qr/Unknown layout 'dvorak'\. Choose one of: azerty, qwerty, qwertz/, 'unknown layout is rejected');
eval { classify('teh', 'the', 'dvorak') };
like($@, qr/Unknown layout 'dvorak'/, 'classify rejects an unknown layout');

is(swap_index('teh', 'the'), 1, 'finds a swap in the middle');
is(swap_index('hte', 'the'), 0, 'finds a swap at the start');
is(swap_index('recieve', 'receive'), 3, 'finds a swap inside a longer word');
is(swap_index('abc', 'abc'), -1, 'identical words have no swap');
is(swap_index('abc', 'abd'), -1, 'a substitution is not a swap');
is(swap_index('abc', 'abcd'), -1, 'different lengths have no swap');
is(swap_index('abcd', 'badc'), -1, 'two swaps are not one swap');
is(swap_index('ab', 'ba'), 0, 'a two letter word can swap');

my %cases = (
    'teh the'              => [ 'slip',    'swapped letters' ],
    'recieve receive'      => [ 'gap',     'ie/ei swap' ],
    'wierd weird'          => [ 'gap',     'ie/ei swap' ],
    'thw the'              => [ 'slip',    'adjacent key' ],
    'wprd word'            => [ 'slip',    'adjacent key' ],
    'seperate separate'    => [ 'gap',     'vowel swap' ],
    'hallo hello'          => [ 'gap',     'vowel swap' ],
    'cat cab'              => [ 'unclear', 'other substitution' ],
    'wrd word'             => [ 'slip',    'dropped letter' ],
    'helo hello'           => [ 'gap',     'missing double letter' ],
    'occured occurred'     => [ 'gap',     'missing double letter' ],
    'neccessary necessary' => [ 'gap',     'extra double letter' ],
    'thwe the'             => [ 'slip',    'extra key' ],
    'thqe the'             => [ 'unclear', 'extra letter' ],
    'abcd wxyz'            => [ 'unclear', 'several edits' ],
    'ab abcd'              => [ 'unclear', 'several edits' ],
    'abcde abc'            => [ 'unclear', 'several edits' ],
    'axbyc abc'            => [ 'unclear', 'several edits' ],
    'bc abcd'              => [ 'unclear', 'several edits' ],
);

for my $case (sort keys %cases) {
    my ($typo, $fix) = split ' ', $case;
    is_deeply([ classify($typo, $fix) ], $cases{$case}, "$typo -> $fix");
}

is_deeply([ classify('qat', 'sat', 'qwerty') ], [ 'unclear', 'other substitution' ], 'q and s are far apart on qwerty');
is_deeply([ classify('qat', 'sat', 'azerty') ], [ 'slip', 'adjacent key' ], 'but neighbours on azerty');

done_testing;