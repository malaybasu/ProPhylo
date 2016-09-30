#!/usr/bin/perl -w
use strict;
use File::Spec;
use Carp;
use SeqToolBox::Taxonomy;
use SeqToolBox::File;
use File::Path qw(make_path);
use File::Spec;

#my $taxon = shift;
use DBI;

#	my $blast_dir = File::Spec->catdir( $tmp_dir, "blast" );
#	my $file      = File::Spec->catfile( $blast_dir, $taxon . '.bla' );
umask 0000;

my $file   = shift;
my $db_dir = shift;
my $blast_dir = File::Spec->catdir("$db_dir", "blast");
make_path ($blast_dir);

$db_dir = $blast_dir;

# open( my $infile, $file ) || croak "Can't open $file\n";
my $infile = SeqToolBox::File->new($file)->get_fh();

my $taxonomy = SeqToolBox::Taxonomy->new();
my $last_outfile;
my $out;

while ( my $line = <$infile> ) {
	next if $line =~ /^\#/;
	chomp $line;
	my @f = split( /\t/, $line );
	my $q = $f[0];
	my $s = $f[1];
	my $e = $f[10];
	my $q_gi;
	my $s_gi;

	if ( $q =~ /gi\|(\d+)/ ) {
		$q_gi = $1;
	}

	unless ($q_gi) {
		$q_gi = $q;
	}

	if ( $s =~ /gi\|(\d+)/ ) {
		$s_gi = $1;
	}

	unless ($s_gi) {
		$s_gi = $s;
	}

	my $taxon;
	eval {
	 $taxon = $taxonomy->get_taxon($q_gi);
	};
	warn $@ if $@;
	next unless $taxon;

	my $out_dir = File::Spec->catdir( $db_dir, "$taxon" );

	unless ( -d $out_dir ) {
		mkdir($out_dir) || die "$out_dir i$!";
	}

	my $taxon_class;
	eval {
	 $taxon_class = $taxonomy->get_taxon($s_gi);
	};
	warn $@ if $@;

	next unless $taxon_class;

	my $outfile = File::Spec->catfile( $out_dir, $q_gi . '.bla' );

	#	my $out;
	if ( !$last_outfile ) {
		open( $out, ">>$outfile" ) || die "Can't open $outfile\n";
	}
	elsif ( $last_outfile && ( $last_outfile ne $outfile ) ) {
		close($out);
		open( $out, ">>$outfile" ) || die "Can't open $outfile\n";
	}
	print $out "$q_gi\t$s_gi\t$e\t$taxon_class\n";
	$last_outfile = $outfile;

	#	close($out);
}
close($infile);
exit(0);
