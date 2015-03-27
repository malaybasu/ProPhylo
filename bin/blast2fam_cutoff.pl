#!/usr/bin/env perl
# $Id: blast2fam_cutoff.pl 591 2010-12-16 19:26:19Z malay $

##---------------------------------------------------------------------------##
##  File: blast2fam_cutoff.pl
##
##  Author:
##        Malay <malay@bioinformatics.org>
##
##  Description:
##
#******************************************************************************
#* Copyright (C) 2009 Malay K Basu <malay@bioinformatics.org>
#* This work is distributed under the license of Perl iteself.
###############################################################################

=head1 NAME

blast2fam_cutoff.pl - Script to stastically determine the BLAST e-value cutoff point for a protein family.

=head1 SYNOPSIS

blast2fam_cutoff.pl [options] -o OUTFILE

	Example:
	
	source /usr/local/projects/TUNE/malay/Phyloprof/settings.bsh
    blast2fam_cutoff.pl \
    -i /usr/local/archive/projects/PPP/split_genomes/blast/146891/161353818.bla \
    -d /usr/local/archive/projects/PPP/split_genomes/blastdb/all.peptides.fa \
    -s 1 \
    -m "O_" \
    -o test_cut.out \
    -n 2
	

=head1 DESCRIPTION

Given a blast result file, the program calls some R function to decompose the BLAST result file into three possion distributions. The program uses FLEXMIX package for R. Once decomposed the program takes the top group starting from the lowest e-value. 


=head1 OPTIONS 

=over 4

=item B<--input|-i FILE>

The file name for the BLAST result file. This input file should have a particular structure. The program is designed to operate on the blast result file created for "ppp_grid" software. If you are creating your own file follow this format.
	
	foo<tab>gi<tab><e-value><tab>bar
	
	The program ignores column 1 and 4. Those can be anything. As long as the tab structure is maintained.

	For e.g.
	Foo<tab>gi|12345<tab>10e-10<tab>bar

=item B<--db | -d BLAST_DATABASE>

This is a database created using formatdb with -o option set. That means the database should be indexed.

=item B<--fasta | -s [1|0]>

To create a fasta file with the required group or not. 

=item B<--mark | -m STRING>

If set these string will be prepended to all sequences NOT belonging to the family, i.e. the outgroup. 

=item B<--output | -o FILE>

This is the output file that will be created. Otherwise the output is redirected to STDOUT.

=item B<--numout | -n integer>

This is the number of outgroup sequences (not beloging to the family) that should be included in the output.

=back

=head1 SEE ALSO

PPP_GRID



=head1 COPYRIGHT

Copyright (c) 2009 Malay K Basu <malay@bioinformatics.org>

=head1 AUTHORS

Malay K Basu <malay@bioinformatics.org>

=cut

##---------------------------------------------------------------------------##
## Module dependencies
##---------------------------------------------------------------------------##

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Carp;
use FindBin;
use lib "$FindBin::Bin/../lib";
use File::Spec;
use PhyloProf::FlexMix;
use SeqToolBox::SeqDB;

#use PhyloProf::Algorithm::ppp;

my $blast_file;
my $blast_db;
my $output;
my $help;
my $fasta;
my $mark;
my $numout;

GetOptions(
	'help|h'     => \$help,
	'db|d=s'     => \$blast_db,
	'input|i=s'  => \$blast_file,
	'fasta|s'    => \$fasta,
	'mark|m=s'   => \$mark,
	'output|o=s' => \$output,
	'numout|n=i' => \$numout

		#	'workspace|w=s' => \$workspace,
		#	'taxon|t=i'     => \$taxon,
		#	'profile|p=s'   => \$profile,
		#	'level|l=s'     => \$level,
		#	'project|r=i'   => \$project,
		#	'nodes|n=i'     => \$nodes,
		#	'client'        => \$client,
		#	'copy|c'        => \$copy,
		#	'output|o=s'    => \$output,
		#	'prob=s'        => \$probability,
		#	'serial'      => \$serial

		#			'blast|b'		=> \$blast,
		#			'genome|g=s'	=> \$genome_dir,
		#			'blastdb'	=>\$blastdb,
) or pod2usage( -verbose => 1 );

pod2usage( -verbose => 2 ) if $help;

my @gi_list;
my @e_values;
my @transformed_gi;
my %already_read;

open( my $blast, $blast_file ) || die "Can't open $blast_file\n";
while ( my $line = <$blast> ) {
	chomp $line;
	next if $line =~ /^\#/;
	my @f = split( /\t/, $line );
	if (exists $already_read{$f[1]}) {next;}
	push @gi_list,  $f[1];
	$already_read{$f[1]} = 1;
	push @e_values, $f[2];
}

close($blast);

my $flexmix = PhyloProf::FlexMix->new();
my $cutoff  = $flexmix->classify(@e_values);
print STDERR "Real Cutoff: $cutoff\n";

my %infamily;
my %outfamily;

for ( my $i = 0; $i < @e_values; $i++ ) {

	#	print STDERR $e_values[$i], "\n";
	if ( $e_values[$i] <= $cutoff ) {
		$infamily{ $gi_list[$i] } = 1;

	} else {

		#		print STDERR "Inside else\n";
		my $o_gi = $gi_list[$i];

		# $o_gi = "O_".$o_gi;
		$outfamily{$o_gi} = 1;
	}
}

if ($fasta) {
	open( TMP, ">fastacmd.tmp" ) || die "Can't open fastacmd.tmp\n";
	print TMP join( "\n", @gi_list );
	close TMP;
	system("fastacmd -d $blast_db -p T -i fastacmd\.tmp -o fastacmd.out") == 0
		|| die "Could not retrieve sequence from database\n";
	my $output_handle;

	if ($output) {
		open( OUT, ">$output" ) || die "Can't open $output\n";
		$output_handle = \*OUT;
	} else {
		$output_handle = \*STDOUT;
	}
	my $seqdb = SeqToolBox::SeqDB->new( -file => "fastacmd.out" );
	my $number = 0;
	my $serial = 0;
	while ( my $seq = $seqdb->next_seq ) {
		my $gi = $seq->get_gi();
		$serial++;
		if ( exists $outfamily{$gi} && defined($mark) ) {
			if ( defined($numout) && $number >= $numout ) {
				next;
			}
			$seq->set_id( $mark . $gi .'_'.$serial );
			$number++;
		}else{
			$seq->set_id($gi.'_'.$serial);
		}
		print $output_handle $seq->get_fasta();
	}
	close($output_handle);
} else {
	my $output_handle;

	if ($output) {
		open( OUT, ">$output" ) || die "Can't open $output\n";
		$output_handle = \*OUT;
	} else {
		$output_handle = \*STDOUT;
	}

	foreach my $i (@gi_list) {
		if ( exists $outfamily{$i} && defined($mark) ) {
			print $output_handle $mark, $i, "\n";
		} elsif ( exists $outfamily{$i} ) {
			next;
		} else {
			print $output_handle $i, "\n";
		}
	}
	close($output_handle);
}

#foreach my $i (@transformed_gi) {
#	print $i, "\n";
#}

system ("rm fastacmd.out fastacmd.tmp") == 0 || die "Can't remove temporary files\n";

exit(0);

