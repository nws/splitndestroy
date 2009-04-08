#!/usr/bin/perl
use strict;
use warnings;
use v5.10;

use Fcntl qw/SEEK_SET/;
use Getopt::Std;
use IO::Zlib;

our ($Size, $Prefix, $File, $Nsplits, %Opts);

sub putsplit {
	my ($nr, $buf, $zipped) = @_;
	my $outfn = sprintf($Prefix.'%0'.(length $Nsplits).'d', $nr);
	my $fh;
	if ($zipped) {
		$outfn .= '.gz';
		$fh = IO::Zlib->new($outfn, 'wb9') or die "cannot open output zfile $outfn: $!\n";
	} else {
		open $fh, '>', $outfn or die "cannot open output file $outfn: $!\n";
	}
	print $fh $buf;
	close $fh or die "could not write split $outfn: $!\n";
}

die "$0 [-z] <size_in_bytes> <prefix> <file_to_split_and_destroy>\n" unless @ARGV >= 3;


getopts('z', \%Opts);

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
	putsplit($i, $buf, defined $Opts{z});
	truncate $fh, $i*$Size;
}

close $fh;

unlink $File;
