#!/usr/bin/env perl
# $Id: gi_profile.pl 658 2011-07-28 18:54:29Z malay $

##---------------------------------------------------------------------------##
##  File: gi_profile.pl
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

gi_profile.pl - To find out the distribution of GI's in a profile.

=head1 SYNOPSIS

gi_profile.pl -p <profile_file> -g <gi_file>


=head1 DESCRIPTION

The program takes two files from the command line: proifle file and a gi list file. The profile file should contain the NCBI taxon id (for species) in the first column. The second column shoud contains a either 1 or 0. The gi file should list a set of GI on each line of the file. The software checks if the each GI belongs to a species that is marked as 1. If so it generates an output for each GI printing 1 if the GI is present and 0 if it is absent. It ignore all the other GIs. 


=head1 ARGUMENTS 

=over 4

=item B <-p profile_file>

Format:

<taxon id for species> <\t> <1|0>

=item B <-g gi_file>

A list of GI each present in its own line.

=item B <--fasta | -f> 

The script can optionally create two files 'yes.faa' containing sequences with that turns out to be 1 in the result and 'no.faa' for sequences that turns out to be 0 in the result.

=item B <--database | -d database_file>

By default the scrip will use /usr/local/archive/projects/PPP/split_genomes/blastdb/all.peptides.fa to extract sequence for the fasta file. But you can override this default using this option. Note, this is a pointer to an indexed blast database. 

=back

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
use SeqToolBox;
use SeqToolBox::Taxonomy;

my $help;
my $profile_file;
my $gi_file;
my $blast_db = '/usr/local/archive/projects/PPP/split_genomes/blastdb/all.peptides.fa';
my $fasta;

GetOptions( 'help'        => \$help,
			'profile|p=s' => \$profile_file,
			'gi|g=s'      => \$gi_file,
			'database|d=s' => \$blast_db,
			'fasta|f' => \$fasta
) or pod2usage( -verbose => 1 );

if ( $help || !$profile_file || !$gi_file ) {
	pod2usage( -verbose => 2 );
}

unless (check_file ($profile_file) || check_file ($gi_file)) {
	die "Error: Input files not present: $!.\n";
}

#unless (check_file ($blast_db)) {
#	die "Error: Can't open blast database: $!\n";
#}

my %profile;
my @yes;
my @no;

open (my $p_in, $profile_file) || die "Can't open $profile_file\n";
while (my $line = <$p_in>) {
	chomp $line;
	my ($taxid, $value) = split (/\t/, $line);
	unless ($taxid || $value) {
		next;
	}
	if (exists $profile{$taxid}) {
		die "Duplicate taxon id $taxid in $profile_file\n";
	}
	$profile{$taxid} = $value;
}
close ($p_in) || die "Can't close $profile_file\n";

my $tax = SeqToolBox::Taxonomy->new();


open (my $g_in, $gi_file) || die "Can't open $gi_file\n";

while (my $line = <$g_in>) {
	chomp $line;
	unless ($line) {next;}
	my $taxon_id = $tax->get_taxon($line);
	unless ($taxon_id) {
		die "Can't get taxon_id for GI $line\n";
	}
	if (exists $profile{$taxon_id}) {
		print $line, "\t", $profile{$taxon_id},"\n";
		if ($profile{$taxon_id} == 1 ) {
			push @yes, $line;
		}else {
			push @no, $line;
		}
	}else {
		print STDERR "Taxon id $taxon_id for GI $line not present in the profile: skipping\n";
		next;
	}	
}

close ($g_in) || die "Can't close gi_file\n";

if ($fasta) {
	
	
	if (@yes) {
		print STDERR "Extracting positive sequences to yes.faa...\n";
	get_sequence (\@yes, 'yes.faa');
	}
	if (@no) {
	print STDERR "Extracting negative sequences to no.faa...\n";
	get_sequence (\@no, 'no.faa');
	}
}

sub get_sequence {
	my ($gi_list, $filename) = @_;
	open( TMP, ">fastacmd.tmp" ) || die "Can't open temporary file for writing \n";
	print TMP join( "\n", @{$gi_list} );
	close TMP;
	system("fastacmd -d $blast_db -p T -i fastacmd\.tmp -o fastacmd.out") == 0
		|| die "Could not retrieve sequence from database\n";

	system ("mv fastacmd.out $filename") == 0 ||
	die "Can't rename fastacmd.tmp to $filename\n";
	system ("rm fastacmd.tmp") == 0 ||
	die "Can't remove temporary files\n";

}
sub check_file {
	my $file = shift;
	if (stat $file) {
		return 1;
	}else {
		return;
	}
}
exit(0);

