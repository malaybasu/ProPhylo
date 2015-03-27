#!/usr/bin/perl -w
use strict;
use lib "/home/mbasu/projects/SeqToolBox/lib";
use IO::Zlib;
use Carp;
use File::Spec;

my $file = shift;
my $cutoff = shift;

eval { require SeqToolBox::Taxonomy };
if ($@) {
	croak "This script requires Malay's toolbox. Contact him at mbasu\@jcvi.org.\n";
}

my %already_done;
my %taxa;

my $fh;

if ($file =~ /\.gz$/) {
	$fh = IO::Zlib->new( $file, "rb" );
}else {
	open ($fh, $file) || die "Can't open $file\n";
}

my $taxonomy = SeqToolBox::Taxonomy->new();

while (my $line = <$fh>) {
	chomp $line;
	my @f = split (/\t/,$line);
	if (exists $already_done{$f[0]} && $already_done{$f[0]} > $cutoff) {
		next;
	}
	my $taxon;
	
	if (exists $taxa{$f[0]} ) {
		$taxon = $taxa{$f[0]};
	}else{
		$taxon = $taxonomy->get_taxon ($f[0]);
		next unless $taxon;
		$taxa{$f[0]} = $taxon;	
	
	}
	
#	next unless $taxon;
	unless (-d $taxon) {
		system ("mkdir $taxon") == 0 or die "Can't create $taxon";
	}
	my $gi;
	if ($f[0] =~ /gi\|(\d+)/) {
		$gi = $1;
	}
	die "Can't parse gi from $f[0]" unless $gi;
	my $bla_file = $gi.'.bla';
	my $filename = File::Spec->catfile($taxon,$bla_file);
	if (exists $already_done{$f[0]} && $already_done{$f[0]} < $cutoff) {
		open (my $outfile, ">>$filename") || die "Can't open $filename\n";
		print $outfile $f[0], "\t", $f[2],"\t", $f[1], "\n";
		close ($outfile); 
		#$sth->execute($f[0], $f[2], 0,$f[1]);
		$already_done{$f[0]}++;
	}elsif (!exists $already_done{$f[0]}){
		#$sth->execute($f[0], $f[2], 0,$f[1]);
		open (my $outfile, ">>$filename") || die "Can't open $filename\n";
		print $outfile $f[0], "\t", $f[2],"\t", $f[1], "\n";
		close ($outfile);
		$already_done{$f[0]}++;
	}else {
		
	} 
}

close $fh;
