use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use Typo::Fossils::Store;
use Typo::Fossils::Review qw(review);

my $dir = tempdir(CLEANUP => 1);
my $counter = 0;

sub candidate {
    my ($typo, $fix) = @_;
    return {
        typo             => $typo,
        correction       => $fix,
        distance         => 1,
        typo_count       => 2,
        correction_count => 20,
        confidence       => '0.800',
    };
}

sub run_review {
    my ($input, $candidates, $store) = @_;
    $store //= Typo::Fossils::Store->new(File::Spec->catfile($dir, 'store' . $counter++ . '.json'));

    open my $in, '<', \$input or die $!;
    my $buffer = '';
    open my $out, '>', \$buffer or die $!;

    my $summary = review($candidates, $store, in => $in, out => $out);
    return ($summary, $buffer, $store);
}

my ($summary, $output, $store) = run_review("a\n", [ candidate('recieve', 'receive') ]);
is($summary->{accepted}, 1, 'accept is counted');
is({ $store->accepted }->{recieve}, 'receive', 'accept stores the pair');
like($output, qr/\[1\/1\] recieve -> receive/, 'shows the candidate');
like($output, qr/confidence 0\.800/, 'shows the confidence');
ok(-f $store->path, 'accept saves immediately');
is({ Typo::Fossils::Store->new($store->path)->accepted }->{recieve}, 'receive', 'saved file contains the decision');

($summary, $output, $store) = run_review("r\n", [ candidate('cut', 'cat') ]);
is($summary->{rejected}, 1, 'reject is counted');
ok($store->is_decided('cut', 'cat'), 'reject stores the pair');
is_deeply({ $store->accepted }, {}, 'reject does not accept');

($summary, $output, $store) = run_review("s\n", [ candidate('teh', 'the') ]);
is($summary->{skipped}, 1, 'skip is counted');
ok(!$store->is_decided('teh', 'the'), 'skip leaves the candidate open');
ok(!-e $store->path, 'skip does not write the store');

($summary, $output, $store) = run_review("q\n", [ candidate('a1b', 'abc'), candidate('x1y', 'xyz') ]);
is($summary->{remaining}, 2, 'quit reports everything left');
is($summary->{accepted} + $summary->{rejected} + $summary->{skipped}, 0, 'quit decides nothing');

($summary, $output, $store) = run_review("a\nq\n", [ candidate('recieve', 'receive'), candidate('seperate', 'separate'), candidate('helo', 'hello') ]);
is($summary->{accepted}, 1, 'decisions before quit are kept');
is($summary->{remaining}, 2, 'quit counts the current and later candidates');
like($output, qr/\[2\/3\] seperate -> separate/, 'progress counter advances');

($summary, $output, $store) = run_review("a\n", [ candidate('recieve', 'receive'), candidate('seperate', 'separate') ]);
is($summary->{accepted}, 1, 'end of input after one decision');
is($summary->{remaining}, 1, 'end of input behaves like quit');

($summary, $output, $store) = run_review("e\nreceived\n", [ candidate('recieved', 'received_') ]);
is($summary->{accepted}, 1, 'edit counts as accept');
is({ $store->accepted }->{recieved}, 'received', 'edit stores the typed correction');

($summary, $output, $store) = run_review("e\n\ns\n", [ candidate('teh', 'the') ]);
is($summary->{skipped}, 1, 'blank edit returns to the menu');
like($output, qr/Correction for teh \(blank to cancel\)/, 'edit asks for a correction');

($summary, $output, $store) = run_review("e\nteh\ns\n", [ candidate('teh', 'the') ]);
is($summary->{accepted}, 0, 'editing to the typo itself is ignored');

($summary, $output, $store) = run_review("e\n", [ candidate('teh', 'the') ]);
is($summary->{remaining}, 1, 'end of input during edit behaves like quit');

($summary, $output, $store) = run_review("x\n\nzzz\nA\n", [ candidate('teh', 'the') ]);
is($summary->{accepted}, 1, 'invalid input is ignored and uppercase works');
my @warnings = $output =~ /Please enter a, r, e, s, or q\./g;
is(scalar @warnings, 3, 'invalid input is explained each time');

my $prefilled = Typo::Fossils::Store->new(File::Spec->catfile($dir, 'prefilled.json'));
$prefilled->accept('teh', 'the');
$prefilled->reject('cut', 'cat');
($summary, $output, $store) = run_review("a\n", [ candidate('teh', 'the'), candidate('cut', 'cat') ], $prefilled);
like($output, qr/Nothing to review\./, 'already decided candidates are not shown again');
is($summary->{accepted}, 0, 'nothing is accepted');

($summary, $output, $store) = run_review("a\n", [ candidate('cut', 'cup') ], $prefilled);
is($summary->{accepted}, 1, 'a rejected typo with a new correction is reviewed again');

($summary, $output, $store) = run_review('', []);
like($output, qr/Nothing to review\./, 'no candidates');
is_deeply($summary, { accepted => 0, rejected => 0, skipped => 0, remaining => 0 }, 'empty summary');

done_testing;