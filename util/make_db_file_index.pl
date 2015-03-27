#!/usr/bin/perl -w
use strict;
use IO::Zlib;


my $directory = shift;
my $hash;

opendir(DIR, $directory) || die "Can't open $directory\n";
while (my $file = readdir(DIR)) {
	next unless $file =~ /^bcp\_all\_vs\_all\_(.)*.gz$/;
	print STDERR $file, "\n";
	my $fh = IO::Zlib->new();
	my $fullname = $directory.'/'. $file;
	$fh->open ($fullname,"rb") || die "Can't open $file\n";
	while (my $line = <$fh>) {
		chomp $line;
		my @f = split (/\t/, $line);
		$hash->{$f[9]}->{$file} = 1;
	}
	$fh->close()
}
close(DIR);

foreach my $id (sort keys %{$hash}) {
	my @files = sort keys %{$hash->{$id}};
	print $id, "\t", join("\t", @files), "\n";
}

