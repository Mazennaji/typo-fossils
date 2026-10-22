package Typo::Fossils::Reader;

use strict;
use warnings;
use utf8;
use Exporter 'import';
use File::Find ();
use Encode qw(decode FB_DEFAULT);

our @EXPORT_OK = qw(find_files files_since read_file);

sub find_files {
    my (@paths) = @_;
    my @files;

    for my $path (@paths) {
        if (-d $path) {
            File::Find::find(
                {
                    preprocess => sub { grep { !/^\./ } @_ },
                    wanted     => sub {
                        push @files, $File::Find::name
                            if -f $_ && /\.(?:txt|md|markdown)\z/i;
                    },
                },
                $path
            );
        }
        elsif (-f $path) {
            push @files, $path;
        }
        else {
            warn "Skipping $path: not found\n";
        }
    }

    return sort @files;
}

sub files_since {
    my ($epoch, @files) = @_;
    return grep {
        my $mtime = (stat $_)[9];
        defined $mtime && $mtime >= $epoch;
    } @files;
}

sub read_file {
    my ($file) = @_;
    open my $fh, '<:raw', $file or die "Cannot open $file: $!\n";
    local $/;
    my $bytes = <$fh>;
    close $fh;
    return decode('UTF-8', $bytes // '', FB_DEFAULT);
}

1;