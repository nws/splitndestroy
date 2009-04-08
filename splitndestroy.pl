#!/usr/bin/perl
# splitndestroy.pl - splits a file into bits without using up twice as much disk space
# Copyright (C) 2009 nws
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use v5.8;

use Fcntl qw/SEEK_SET/;
use Getopt::Std;

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
