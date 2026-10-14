use strict;
use warnings;
use utf8;
use Test::More;
use Typo::Fossils::Tokenizer qw(tokenize);

binmode Test::More->builder->$_, ':encoding(UTF-8)'
    for qw(output failure_output todo_output);

is_deeply([ tokenize("Teh quick, brown fox!") ], [qw(teh quick brown fox)], 'splits and lowercases');
is_deeply([ tokenize("Don't stop") ], [ "don't", 'stop' ], 'keeps contractions');
is_deeply([ tokenize("don\x{2019}t") ], [ "don't" ], 'normalizes curly apostrophes');
is_deeply([ tokenize("see https://example.com/a?b=c now") ], [qw(see now)], 'drops urls');
is_deeply([ tokenize('mail me@example.com today') ], [qw(mail today)], 'drops email addresses');
is_deeply([ tokenize("a I of") ], [ 'of' ], 'drops single-letter tokens');
is_deeply([ tokenize("Cafe\x{301}") ], [ "caf\x{e9}" ], 'composes decomposed accents');
is_deeply([ tokenize("route66 and x2y") ], [qw(route and)], 'splits on digits');
is_deeply([ tokenize('') ], [], 'empty string');
is_deeply([ tokenize(undef) ], [], 'undef');

done_testing;