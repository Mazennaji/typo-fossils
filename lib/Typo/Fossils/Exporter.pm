package Typo::Fossils::Exporter;

use strict;
use warnings;
use utf8;
use Exporter 'import';

our @EXPORT_OK = qw(export_pairs supported_formats infer_format write_output);

my %EXTENSIONS = (
    yml   => 'espanso',
    yaml  => 'espanso',
    vim   => 'vim',
    plist => 'macos',
);

sub yaml_quote {
    my ($text) = @_;
    $text =~ s/\\/\\\\/g;
    $text =~ s/"/\\"/g;
    $text =~ s/\n/\\n/g;
    $text =~ s/\t/\\t/g;
    return qq{"$text"};
}

sub vim_escape {
    my ($text) = @_;
    $text =~ s/</<lt>/g;
    $text =~ s/\|/<Bar>/g;
    return $text;
}

sub xml_escape {
    my ($text) = @_;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    return $text;
}

sub render_espanso {
    my ($pairs) = @_;
    return ("matches: []\n", []) unless %$pairs;

    my $text = "matches:\n";
    for my $typo (sort keys %$pairs) {
        $text .= '  - trigger: ' . yaml_quote($typo) . "\n";
        $text .= '    replace: ' . yaml_quote($pairs->{$typo}) . "\n";
        $text .= "    word: true\n";
        $text .= "    propagate_case: true\n";
    }
    return ($text, []);
}

sub render_vim {
    my ($pairs) = @_;
    my $text = '';
    my @skipped;

    for my $typo (sort keys %$pairs) {
        my $fix = $pairs->{$typo};
        if ($typo !~ /\A[\p{L}\p{M}\p{N}_]+\z/ || $fix =~ /[\x00-\x1f\x7f]/) {
            push @skipped, $typo;
            next;
        }
        $text .= 'iabbrev ' . $typo . ' ' . vim_escape($fix) . "\n";
    }
    return ($text, \@skipped);
}

sub render_macos {
    my ($pairs) = @_;
    my $text = qq{<?xml version="1.0" encoding="UTF-8"?>\n}
             . qq{<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n}
             . qq{<plist version="1.0">\n<array>\n};
    my @skipped;

    for my $typo (sort keys %$pairs) {
        my $fix = $pairs->{$typo};
        if ("$typo$fix" =~ /[\x00-\x08\x0B\x0C\x0E-\x1F]/) {
            push @skipped, $typo;
            next;
        }
        $text .= "\t<dict>\n"
              .  "\t\t<key>phrase</key>\n"
              .  "\t\t<string>" . xml_escape($fix) . "</string>\n"
              .  "\t\t<key>shortcut</key>\n"
              .  "\t\t<string>" . xml_escape($typo) . "</string>\n"
              .  "\t</dict>\n";
    }

    $text .= "</array>\n</plist>\n";
    return ($text, \@skipped);
}

my %RENDERERS = (
    espanso => \&render_espanso,
    vim     => \&render_vim,
    macos   => \&render_macos,
);

sub supported_formats { return sort keys %RENDERERS }

sub infer_format {
    my ($path) = @_;
    return undef unless defined $path && $path =~ /\.([^.\/\\]+)\z/;
    return $EXTENSIONS{ lc $1 };
}

sub export_pairs {
    my ($format, $pairs) = @_;
    my $render = $RENDERERS{ $format // '' }
        or die sprintf("Unknown format '%s'. Choose one of: %s\n", $format // '', join(', ', supported_formats()));
    return $render->($pairs);
}

sub write_output {
    my ($path, $text) = @_;
    my $tmp = "$path.tmp";
    open my $fh, '>:encoding(UTF-8)', $tmp or die "Cannot write $tmp: $!\n";
    print {$fh} $text;
    close $fh or die "Cannot write $tmp: $!\n";
    rename $tmp, $path or die "Cannot replace $path: $!\n";
}

1;