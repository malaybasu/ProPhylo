#!/usr/bin/perl -w
use strict;
my $file = shift;
my $map = shift;
my %map;

open (MAP, $map) || die "Can't open map\n";
while (my $line = <MAP>) {
	chomp $line;
	my @f = split (/\t/, $line);
	$map{$f[1]} = $f[0];
	
}
close MAP;

open (FILE, $file) || die "Can't open $file\n";
while (my $line = <FILE>) {
	chomp $line;
	my @f = split(/\t/, $line);
	if (exists $map{$f[0]}) {
 	print $map{$f[0]}, "\t",$f[1], "\n";
	}
	}