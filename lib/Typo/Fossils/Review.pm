package Typo::Fossils::Review;

use strict;
use warnings;
use utf8;
use Exporter 'import';

our @EXPORT_OK = qw(review);

sub trim {
    my ($text) = @_;
    $text =~ s/^\s+|\s+\z//g;
    return $text;
}

sub review {
    my ($candidates, $store, %opt) = @_;
    my $in  = $opt{in}  // \*STDIN;
    my $out = $opt{out} // \*STDOUT;

    my @pending = grep { !$store->is_decided($_->{typo}, $_->{correction}) } @$candidates;
    my %summary = (accepted => 0, rejected => 0, skipped => 0, remaining => 0);
    my $total   = @pending;

    if (!$total) {
        print {$out} "Nothing to review.\n";
        return \%summary;
    }

    my $position = 0;

    CANDIDATE:
    while (my $candidate = shift @pending) {
        $position++;
        my ($typo, $fix) = @{$candidate}{qw(typo correction)};

        my $label = defined $candidate->{kind} ? ", $candidate->{kind} ($candidate->{reason})" : '';

        printf {$out} "\n[%d/%d] %s -> %s   seen %d, common %d, confidence %s%s\n",
            $position, $total, $typo, $fix,
            @{$candidate}{qw(typo_count correction_count confidence)}, $label;

        while (1) {
            print {$out} "[a]ccept  [r]eject  [e]dit  [s]kip  [q]uit > ";
            my $line = <$in>;

            if (!defined $line) {
                print {$out} "\n";
                $summary{remaining} = 1 + @pending;
                return \%summary;
            }

            my $choice = lc substr(trim($line), 0, 1);

            if ($choice eq 'a') {
                $store->accept($typo, $fix);
                $store->save;
                $summary{accepted}++;
                next CANDIDATE;
            }

            if ($choice eq 'r') {
                $store->reject($typo, $fix);
                $store->save;
                $summary{rejected}++;
                next CANDIDATE;
            }

            if ($choice eq 's') {
                $summary{skipped}++;
                next CANDIDATE;
            }

            if ($choice eq 'q') {
                $summary{remaining} = 1 + @pending;
                return \%summary;
            }

            if ($choice eq 'e') {
                print {$out} "Correction for $typo (blank to cancel) > ";
                my $edited = <$in>;

                if (!defined $edited) {
                    print {$out} "\n";
                    $summary{remaining} = 1 + @pending;
                    return \%summary;
                }

                $edited = trim($edited);
                next if $edited eq '' || $edited eq $typo;

                $store->accept($typo, $edited);
                $store->save;
                $summary{accepted}++;
                next CANDIDATE;
            }

            print {$out} "Please enter a, r, e, s, or q.\n";
        }
    }

    return \%summary;
}

1;