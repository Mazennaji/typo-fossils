use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use Typo::Fossils::Counter qw(count_words count_paths top_words);

my $counts = count_words("the cat the dog the cat teh");
is_deeply($counts, { the => 3, cat => 2, dog => 1, teh => 1 }, 'counts words');

count_words("the bird", $counts);
is($counts->{the}, 4, 'accumulates into an existing table');
is($counts->{bird}, 1, 'adds new words');

is_deeply(
    [ top_words($counts) ],
    [ [ the => 4 ], [ cat => 2 ], [ bird => 1 ], [ dog => 1 ], [ teh => 1 ] ],
    'sorts by count then alphabetically'
);
is_deeply([ top_words($counts, limit => 2) ], [ [ the => 4 ], [ cat => 2 ] ], 'limit');
is_deeply([ top_words($counts, min_count => 2) ], [ [ the => 4 ], [ cat => 2 ] ], 'min_count');

my $dir = tempdir(CLEANUP => 1);
mkdir File::Spec->catdir($dir, 'sub');
mkdir File::Spec->catdir($dir, '.hidden');

for my $spec (
    [ 'a.txt',        "alpha beta alpha" ],
    [ 'sub/b.md',     "beta gamma" ],
    [ 'skip.log',     "ignored words here" ],
    [ '.hidden/c.txt', "secret" ],
) {
    my ($name, $body) = @$spec;
    open my $fh, '>:encoding(UTF-8)', File::Spec->catfile($dir, split m{/}, $name) or die $!;
    print {$fh} $body;
    close $fh;
}

my $from_dir = count_paths($dir);
is_deeply($from_dir, { alpha => 2, beta => 2, gamma => 1 }, 'walks directories, filters extensions, skips hidden');

my $single = count_paths(File::Spec->catfile($dir, 'skip.log'));
is_deeply($single, { ignored => 1, words => 1, here => 1 }, 'explicit files are read regardless of extension');

done_testing;