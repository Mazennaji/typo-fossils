use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use Typo::Fossils::Store;

binmode Test::More->builder->$_, ':encoding(UTF-8)'
    for qw(output failure_output todo_output);

my $dir  = tempdir(CLEANUP => 1);
my $path = File::Spec->catfile($dir, 'nested', 'deeper', 'decisions.json');

my $store = Typo::Fossils::Store->new($path);
is_deeply({ $store->accepted }, {}, 'starts empty when the file does not exist');
is($store->path, $path, 'reports its path');
ok(!$store->is_decided('teh', 'the'), 'nothing is decided at first');

$store->accept('teh', 'the');
$store->accept('recieve', 'receive');
$store->reject('cut', 'cat');

ok($store->is_decided('teh', 'the'), 'accepted pair is decided');
ok($store->is_decided('teh', 'ten'), 'any correction counts once a typo is accepted');
ok($store->is_decided('cut', 'cat'), 'rejected pair is decided');
ok(!$store->is_decided('cut', 'cup'), 'a different correction for a rejected typo is still open');

$store->save;
ok(-f $path, 'save creates missing directories and the file');
ok(!-e "$path.tmp", 'no temp file is left behind');

my $reloaded = Typo::Fossils::Store->new($path);
is_deeply({ $reloaded->accepted }, { teh => 'the', recieve => 'receive' }, 'accepted pairs survive a reload');
ok($reloaded->is_decided('cut', 'cat'), 'rejected pairs survive a reload');
ok(!$reloaded->is_decided('cut', 'cup'), 'rejection stays specific to its pair');

$reloaded->reject('teh', 'the');
ok(!exists { $reloaded->accepted }->{teh}, 'rejecting removes an accepted pair');
$reloaded->accept('cut', 'cat');
is({ $reloaded->accepted }->{cut}, 'cat', 'accepting overrides a rejection');
ok($reloaded->is_decided('cut', 'cup'), 'and then any correction counts as decided');

$reloaded->accept('caffe', "caf\x{e9}");
$reloaded->save;
my $unicode = Typo::Fossils::Store->new($path);
is({ $unicode->accepted }->{caffe}, "caf\x{e9}", 'unicode corrections round trip');

my $empty = File::Spec->catfile($dir, 'empty.json');
open my $efh, '>', $empty or die $!;
close $efh;
is_deeply({ Typo::Fossils::Store->new($empty)->accepted }, {}, 'an empty file is treated as a fresh store');

my $broken = File::Spec->catfile($dir, 'broken.json');
open my $bfh, '>', $broken or die $!;
print {$bfh} '{ not json';
close $bfh;
eval { Typo::Fossils::Store->new($broken) };
like($@, qr/Invalid store file/, 'a corrupt file is reported');

my $wrong = File::Spec->catfile($dir, 'wrong.json');
open my $wfh, '>', $wrong or die $!;
print {$wfh} '[1, 2, 3]';
close $wfh;
eval { Typo::Fossils::Store->new($wrong) };
like($@, qr/Invalid store file/, 'a file with the wrong shape is reported');

{
    local $ENV{XDG_CONFIG_HOME} = '/custom/config';
    is(Typo::Fossils::Store::default_path(), '/custom/config/typo-fossils/decisions.json', 'default path honours XDG_CONFIG_HOME');
}

done_testing;