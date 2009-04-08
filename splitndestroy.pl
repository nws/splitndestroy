#!/usr/bin/perl
use strict;
use warnings;
use v5.10;

use Fcntl qw/SEEK_SET/;

our ($Size, $Prefix, $File, $Nsplits);

sub putsplit {
	my ($nr, $buf) = @_;
	my $outfn = sprintf($Prefix.'%0'.(length $Nsplits).'d', $nr);
	open my $fh, '>', $outfn or die "cannot open output file $outfn: $!\n";
	print $fh $buf;
	close $fh or die "could not write split $outfn: $!\n";
}

die "$0 <size_in_bytes> <prefix> <file_to_split_and_destroy>\n" unless @ARGV == 3;

($Size, $Prefix, $File) = @ARGV;

die "cannot open file $File for r/w\n" unless -W $File;
{ no warnings; $Size += 0 }
die "size must be > 0\n" unless $Size;

open my $fh, '+<', $File or die "cannot open $File for r/w: $!\n";
my $total_size = (stat $fh)[7];
$Nsplits = int($total_size/$Size);
if ($total_size % $Size) {
	$Nsplits++;
}

for (my $i = $Nsplits-1; $i >= 0; --$i) {
	seek $fh, $i*$Size, SEEK_SET;
	read $fh, my($buf), $Size;
	putsplit($i, $buf);
	truncate $fh, $i*$Size;
}

close $fh;

unlink $File;
