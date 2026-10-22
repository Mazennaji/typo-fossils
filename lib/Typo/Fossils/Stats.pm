package Typo::Fossils::Stats;

use strict;
use warnings;
use utf8;
use Exporter 'import';

our @EXPORT_OK = qw(
    typo_total rate trend headline describe hall_of_fame retired
    format_change commify report
);

sub by_date {
    return sort { $a->{date} cmp $b->{date} } @_;
}

sub commify {
    my ($number) = @_;
    my $text = reverse $number;
    $text =~ s/(\d{3})(?=\d)/$1,/g;
    return scalar reverse $text;
}

sub format_change {
    my ($change) = @_;
    return '-' unless defined $change;

    my $rounded = sprintf('%.0f', $change);
    return '0%' if $rounded == 0;
    return sprintf('%+d%%', $rounded);
}

sub typo_total {
    my ($snapshot) = @_;
    my $total = 0;
    $total += $_->{count} for values %{ $snapshot->{typos} };
    return $total;
}

sub rate {
    my ($snapshot) = @_;
    return $snapshot->{words} ? typo_total($snapshot) / $snapshot->{words} * 1000 : 0;
}

sub change {
    my ($from, $to) = @_;
    return undef unless $from;
    return ($to - $from) / $from * 100;
}

sub trend {
    my @snapshots = by_date(@_);
    my (@rows, $previous);

    for my $snapshot (@snapshots) {
        my $rate = rate($snapshot);
        push @rows, {
            date   => $snapshot->{date},
            words  => $snapshot->{words},
            typos  => typo_total($snapshot),
            rate   => $rate,
            change => defined $previous ? change($previous, $rate) : undef,
        };
        $previous = $rate;
    }
    return @rows;
}

sub headline {
    my @snapshots = by_date(@_);
    return undef if @snapshots < 2;

    my ($first, $last) = @snapshots[0, -1];
    my ($from, $to)    = (rate($first), rate($last));

    return {
        from_date => $first->{date},
        to_date   => $last->{date},
        from_rate => $from,
        to_rate   => $to,
        change    => change($from, $to),
    };
}

sub describe {
    my ($headline) = @_;
    my ($from, $to, $date) = @{$headline}{qw(from_rate to_rate from_date)};

    return 'No tracked typos in either snapshot.' unless $from || $to;
    return sprintf('Up from %.1f to %.1f per 1,000 words since %s.', $from, $to, $date)
        unless defined $headline->{change};

    my $percent = sprintf('%.0f', abs $headline->{change});
    return sprintf('Holding steady at %.1f per 1,000 words since %s.', $to, $date) if $percent == 0;

    return sprintf('%s %d%% since %s (%.1f to %.1f per 1,000 words).',
        ($headline->{change} < 0 ? 'Down' : 'Up'), $percent, $date, $from, $to);
}

sub hall_of_fame {
    my ($snapshots, %opt) = @_;
    my %entry;

    for my $snapshot (by_date(@$snapshots)) {
        for my $typo (keys %{ $snapshot->{typos} }) {
            my $item = $snapshot->{typos}{$typo};
            next unless $item->{count} > 0;

            my $row = $entry{$typo} //= { typo => $typo, total => 0, snapshots => 0 };
            $row->{total} += $item->{count};
            $row->{snapshots}++;
            $row->{fix}       = $item->{fix};
            $row->{last_seen} = $snapshot->{date};
        }
    }

    my @rows = sort { $b->{total} <=> $a->{total} || $a->{typo} cmp $b->{typo} } values %entry;
    splice @rows, $opt{limit} if defined $opt{limit} && $opt{limit} < @rows;
    return @rows;
}

sub retired {
    my ($snapshots) = @_;
    my @sorted = by_date(@$snapshots);
    return () if @sorted < 2;

    my $latest = pop @sorted;
    my (%total, %fix);

    for my $snapshot (@sorted) {
        for my $typo (keys %{ $snapshot->{typos} }) {
            my $item = $snapshot->{typos}{$typo};
            next unless $item->{count} > 0;
            $total{$typo} += $item->{count};
            $fix{$typo} = $item->{fix};
        }
    }

    my @rows = map { +{ typo => $_, fix => $fix{$_}, total => $total{$_} } }
               grep { !($latest->{typos}{$_} && $latest->{typos}{$_}{count} > 0) }
               keys %total;

    return sort { $b->{total} <=> $a->{total} || $a->{typo} cmp $b->{typo} } @rows;
}

sub report {
    my ($snapshots, %opt) = @_;
    my $top   = $opt{top} // 10;
    my @snaps = by_date(@$snapshots);

    return "No history yet. Run typo-fossils track PATH first.\n" unless @snaps;

    my ($words, $typos) = (0, 0);
    for my $snapshot (@snaps) {
        $words += $snapshot->{words};
        $typos += typo_total($snapshot);
    }

    my ($first, $last) = ($snaps[0]{date}, $snaps[-1]{date});
    my $out = sprintf("Snapshots: %d (%s)\nWords tracked: %s\nTypos found: %s\n\n",
        scalar @snaps, ($first eq $last ? $first : "$first to $last"), commify($words), commify($typos));

    $out .= "Typo rate per 1,000 words\n";
    $out .= sprintf("%-10s  %7s  %5s  %6s  %6s\n", qw(DATE WORDS TYPOS RATE CHANGE));
    $out .= sprintf("%-10s  %7s  %5d  %6.1f  %6s\n",
        $_->{date}, commify($_->{words}), $_->{typos}, $_->{rate}, format_change($_->{change}))
        for trend(@snaps);

    my $headline = headline(@snaps);
    $out .= "\n" . ($headline ? describe($headline) : 'Track again after more writing to see a trend.') . "\n";

    my @fame = hall_of_fame(\@snaps, limit => $top);
    if (@fame) {
        my $rank = 0;
        $out .= "\nHall of fame\n";
        $out .= sprintf("%-4s  %-16s  %-16s  %5s  %9s  %s\n", '#', qw(TYPO FIX TOTAL SNAPSHOTS), 'LAST SEEN');
        $out .= sprintf("%-4d  %-16s  %-16s  %5d  %9d  %s\n", ++$rank, @{$_}{qw(typo fix total snapshots last_seen)})
            for @fame;
    }
    else {
        $out .= "\nNo tracked typos in any snapshot yet.\n";
    }

    my @gone = retired(\@snaps);
    if (@gone) {
        my @shown = @gone > $top ? @gone[0 .. $top - 1] : @gone;
        my $more  = @gone - @shown;
        $out .= "\nRetired (not in your latest snapshot): "
              . join(', ', map { "$_->{typo} ($_->{total})" } @shown)
              . ($more ? " and $more more" : '') . "\n";
    }

    return $out;
}

1;