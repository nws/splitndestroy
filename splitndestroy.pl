#!/usr/bin/perl
use strict;
use warnings;
use v5.8;

use Fcntl qw/SEEK_SET/;
use Getopt::Std;
use IO::Zlib;

use constant BUFSIZE => 8192;

our ($Size, $Prefix, $File, $Nsplits, %Opts);

sub opensplit {
	my ($nr, $zipped) = @_;
	my $outfn = sprintf($Prefix.'%0'.(length $Nsplits).'d', $nr);
	my $fh;
	if ($zipped) {
		$outfn .= '.gz';
		open $fh, '| gzip > '.$outfn or die "cannot open output zfile $outfn: $!\n";
	} else {
		open $fh, '>', $outfn or die "cannot open output file $outfn: $!\n";
	}
	return $fh;
}

die "$0 [-z] <size_in_bytes> <prefix> <file_to_split_and_destroy>\n" unless @ARGV >= 3;

getopts('z', \%Opts);

($Size, $Prefix, $File) = @ARGV;

die "cannot open file $File for r/w\n" unless -W $File;
if ($Size =~ m/^(\d+)([KMG]?)$/) {
	$Size = $1;

	my $u = $2;
	if ($u eq 'K') {
		$Size *= 1024;
	} elsif ($u eq 'M') {
		$Size *= 1024*1024;
	} elsif ($u eq 'G') {
		$Size *= 1024*1024*1024;
	}
} else {
	die "size must be a number, optionally followed by one of K,M,G\n";
}


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

	my $splfh = opensplit($i, defined $Opts{z});
	while (read $fh, my($buf), BUFSIZE) {
		print $splfh $buf;
	}
	close $splfh or die "cannot write to outfile $i\n";

	truncate $fh, $i*$Size;
}

close $fh;

unlink $File;
