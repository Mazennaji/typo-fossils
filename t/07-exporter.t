use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use Typo::Fossils::Exporter qw(export_pairs supported_formats infer_format write_output);

binmode Test::More->builder->$_, ':encoding(UTF-8)'
    for qw(output failure_output todo_output);

sub slurp {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "Cannot read $path: $!";
    local $/;
    my $bytes = <$fh>;
    close $fh;
    return $bytes;
}

is_deeply([ supported_formats() ], [qw(espanso macos vim)], 'lists the three formats');

is(infer_format('typos.yml'), 'espanso', 'yml maps to espanso');
is(infer_format('typos.YAML'), 'espanso', 'extension match ignores case');
is(infer_format('/a/b/typos.vim'), 'vim', 'vim extension');
is(infer_format('typos.plist'), 'macos', 'plist extension');
is(infer_format('typos.txt'), undef, 'unknown extension');
is(infer_format('typos'), undef, 'no extension');
is(infer_format(undef), undef, 'undef path');

my ($yaml, $yaml_skipped) = export_pairs('espanso', { teh => 'the', recieve => 'receive' });
is($yaml, <<'YAML', 'espanso output is sorted and complete');
matches:
  - trigger: "recieve"
    replace: "receive"
    word: true
    propagate_case: true
  - trigger: "teh"
    replace: "the"
    word: true
    propagate_case: true
YAML
is_deeply($yaml_skipped, [], 'espanso skips nothing');

my ($quoted) = export_pairs('espanso', { x => 'say "hi" \\ there' });
my $expected_quote = 'replace: "say \"hi\" \\\\ there"';
ok(index($quoted, $expected_quote) >= 0, 'espanso escapes quotes and backslashes');

my ($unicode_yaml) = export_pairs('espanso', { caffe => "caf\x{e9}" });
like($unicode_yaml, qr/replace: "caf\x{e9}"/, 'espanso keeps unicode as is');

is((export_pairs('espanso', {}))[0], "matches: []\n", 'espanso empty list is valid yaml');

my ($vim, $vim_skipped) = export_pairs('vim', { teh => 'the', ive => "I've", "wouldn't" => 'would not' });
is($vim, "iabbrev ive I've\niabbrev teh the\n", 'vim output is sorted');
is_deeply($vim_skipped, ["wouldn't"], 'vim skips triggers with punctuation');

my ($vim_escaped) = export_pairs('vim', { bar => 'a|b', lt => '<Esc>' });
is($vim_escaped, "iabbrev bar a<Bar>b\niabbrev lt <lt>Esc>\n", 'vim escapes pipes and angle brackets');

my ($vim_control, $vim_control_skipped) = export_pairs('vim', { tab => "a\tb", ok => 'fine' });
is($vim_control, "iabbrev ok fine\n", 'vim drops replacements with control characters');
is_deeply($vim_control_skipped, ['tab'], 'and reports them');

my ($vim_unicode) = export_pairs('vim', { caffe => "caf\x{e9}" });
is($vim_unicode, "iabbrev caffe caf\x{e9}\n", 'vim keeps unicode corrections');

my ($plist, $plist_skipped) = export_pairs('macos', { teh => 'the' });
is(
    $plist,
    qq{<?xml version="1.0" encoding="UTF-8"?>\n}
  . qq{<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n}
  . qq{<plist version="1.0">\n<array>\n}
  . "\t<dict>\n\t\t<key>phrase</key>\n\t\t<string>the</string>\n\t\t<key>shortcut</key>\n\t\t<string>teh</string>\n\t</dict>\n"
  . "</array>\n</plist>\n",
    'macos output matches the plist layout'
);
is_deeply($plist_skipped, [], 'macos skips nothing for plain words');

my ($escaped_plist) = export_pairs('macos', { amp => 'a & b <c>' });
like($escaped_plist, qr{<string>a &amp; b &lt;c&gt;</string>}, 'macos escapes xml characters');

my ($bad_plist, $bad_plist_skipped) = export_pairs('macos', { bad => "a\x{1}b", good => 'ok' });
is_deeply($bad_plist_skipped, ['bad'], 'macos skips control characters');
unlike($bad_plist, qr/<string>bad<\/string>/, 'and leaves them out');
like($bad_plist, qr/<string>good<\/string>/, 'but keeps the rest');

my @order = export_pairs('macos', { zeta => 'z1', alpha => 'a1' });
ok(index($order[0], 'alpha') < index($order[0], 'zeta'), 'macos output is sorted');

eval { export_pairs('docx', {}) };
like($@, qr/Unknown format 'docx'\. Choose one of: espanso, macos, vim/, 'unknown format is rejected');
eval { export_pairs(undef, {}) };
like($@, qr/Unknown format ''/, 'undefined format is rejected');

my $dir  = tempdir(CLEANUP => 1);
my $path = File::Spec->catfile($dir, 'out.vim');

write_output($path, "iabbrev caffe caf\x{e9}\n");
ok(-f $path, 'write_output creates the file');
ok(!-e "$path.tmp", 'and leaves no temp file');
is(slurp($path), "iabbrev caffe caf\xc3\xa9\n", 'and writes utf-8');

write_output($path, "second\n");
is(slurp($path), "second\n", 'write_output replaces an existing file');

eval { write_output(File::Spec->catfile($dir, 'missing', 'out.vim'), 'x') };
like($@, qr/Cannot write/, 'an unwritable path is reported');

done_testing;