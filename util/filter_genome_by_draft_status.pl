#!/usr/bin/env perl
# $Id$

##---------------------------------------------------------------------------##
##  File: filter_genome_by_draft_status.pl
##
##  Author:
##        Malay <malay@bioinformatics.org>
##
##  Description:
##
#******************************************************************************
#* Copyright (C) 2011 Malay K Basu <malay@bioinformatics.org>
#* This work is distributed under the license of Perl iteself.
###############################################################################

=head1 NAME

filter_genome_by_draft_status.pl - One line description.

=head1 SYNOPSIS

filter_genome_by_draft_status.pl [options] -o <option>


=head1 DESCRIPTION

Write a description of your prgram. 


=head1 ARGUMENTS 

=over 4

=item B<--option|-o>

First option.



=back

=head1 OPTIONS

Something here.


=head1 SEE ALSO

=head1 COPYRIGHT

Copyright (c) 2011 Malay K Basu <malay@bioinformatics.org>

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
use SeqToolBox::SeqDB;
use SeqToolBox::Taxonomy;
use File::Spec;
use Carp;

##---------------------------------------------------------------------------##
# Option processing
#  e.g.
#   -t: Single letter binary option
#   -t=s: String parameters
#   -t=i: Number paramters
##---------------------------------------------------------------------------##

my %options = ();    # this hash will have the options

#
# Get the supplied command line options, and set flags
#

GetOptions( \%options, 'help|?' ) || pod2usage( -verbose => 0 );

my ( $complete_dir, $draft_dir ) = @ARGV;
my $tax = SeqToolBox::Taxonomy->new();

my %c_names;
my %c_sp;
my %c_sp_set;
my %d_names;
my %d_sp;
my %d_sp_set;

#%my %complete_genome_sp_list;
#my %draft_genome_sp_list;
#my %complete_genomes;
#my %draft_genomes;

get_species_list( $complete_dir, \%c_names, \%c_sp, \%c_sp_set );
get_species_list( $draft_dir,    \%d_names, \%d_sp, \%d_sp_set );

print "Genome\tTaxid\tSpecies\tStatus\tDelete_flag\n";

foreach my $name ( sort { $c_names{$a} cmp $c_names{$b} }
				   keys %c_names )
{
	print $c_names{$name}, "\t", $name, "\t", $c_sp{$name},"\t", "complete", "\t",
		"keep\n";
}

foreach my $name (
	sort {
		$d_names{$a} cmp $d_names{$b}
	} keys %d_names
	)
{
	print $d_names{$name}, "\t", $name,"\t",$d_sp{$name}, "\t", "draft", "\t";

	if ( exists $c_sp_set{$d_sp{$name}} ) {
		print "delete\n";
	} else {
		print "-\n";
	}
}

sub get_species_list {
	my ( $dir, $names, $sp, $sp_set ) = @_;
	opendir( DIR, $dir ) || die "Can't open $dir\n";

	while ( my $subdir = readdir(DIR) ) {
		next if ( $subdir =~ /^\.$/ || $subdir =~ /^\.\.$/ );
		print STDERR "Subdir $subdir\n";
		my $full_subdir = File::Spec->catdir( $dir, $subdir );
		opendir( SD, $full_subdir ) || die "Can't open $full_subdir\n";
		my $found = 0;
		
		while ( my $file = readdir(SD) ) {
			last if $found;
			
			#print STDERR $subdir,"\t", $file, "\n";
			next unless ( $file =~ /\.faa$/ || $file =~ /\.fas$/ );
			print STDERR $subdir, "\t", $file, "\n";
			my $full_file_name = File::Spec->catfile( $full_subdir, $file );
			my $seqdb = SeqToolBox::SeqDB->new( -file => $full_file_name );
			croak("Could not create seqdb from $full_file_name") unless $seqdb;
			my $species_tax_id="";
			my $tax_id ="";

			while ( my $seq = $seqdb->next_seq() ) {
				print STDERR "Specis $species_tax_id Tax_id $tax_id\n";
				print STDERR "Inside seq loop\n";
				last if $species_tax_id;
				print STDERR "never reached\n";
				
				croak("Could not create seqdb object") unless ($seq);
				my $gi = $seq->get_gi();
				print STDERR "Gi: $gi\n";

				#get the first seqid sequence;
				#			my $gi = $seqdb->next_seq()->get_gi();
				croak("Could not parse gi from $full_file_name\n") unless $gi;
				$tax_id = $tax->get_taxon($gi);

				unless ($tax_id) {
					print STDERR "Error: Could not find tax id for $gi\n";
					next;
				}

				#print STDERR "Gi $gi Tax $tax_id\n";
				my $temp = $tax->collapse_taxon( $tax_id, "species" );

				unless ($temp) {
					print STDERR
						"Error: Could not find species for tax_id $tax_id\n";
					next;
				}
				$species_tax_id = $temp;

			}
			croak("Could not parse tax_id for $subdir") unless $species_tax_id;
			if (exists $names->{$tax_id}) {
				
				print STDERR "Error:Duplicate Taxid $names->{$tax_id} and $subdir\n";
				$found = 1;
				next;
				
			}
			$names->{$tax_id} = $subdir;
			$sp->{$tax_id} = $species_tax_id;
			$sp_set->{$species_tax_id} = 1;
#			$list->{$species_tax_id} = 1;
#			$fulllist->{$tax_id}     = $subdir;
			$found                   = 1;

		}
		close(SD);
		croak "Could not find any sequence file in $full_subdir\n"
			unless $found;
	}
	close(DIR);
}

exit(0);

######################## S U B R O U T I N E S ############################

