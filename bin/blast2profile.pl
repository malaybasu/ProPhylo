#!/usr/bin/env perl
# $Id: hmm3profile.pl 658 2011-07-28 18:54:29Z malay $

use lib '/home/mbasu/projects/SeqToolBox/lib';

##---------------------------------------------------------------------------##
##  File: hmm2profile.pl
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

##---------------------------------------------------------------------------##
## Module dependencies
##---------------------------------------------------------------------------##

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Carp;
use File::Temp;
use Carp;
use Term::ProgressBar;
use SeqToolBox::HMMER::Parser;
use Cwd;

unless ( $ENV{'SEQTOOLBOXDB'} ) {
	croak "SEQTOOLBOXDB not defined\n";
}

## Check for Taxonomy module and Bioperl
#eval { require Bio::SearchIO };
#if ($@) { croak "This script requires Bioperl. I can't find it."; }

eval { require SeqToolBox::Taxonomy };
if ($@) {
	croak
		"This script requires Malay's toolbox. Contact him at mbasu\@jcvi.org.\n";
}

eval { require SeqToolBox::SeqDB };
if ($@) {
	croak
		"This script requires Malay's toolbox. Contact him at mbasu\@jcvi.org.\n";
}

system('which hmmsearch > /dev/null') == 0
	or croak("I can't find HMMER. Install it or add it to path");

##---------------------------------------------------------------------------##
# Option processing
#  e.g.
#   -t: Single letter binary option
#   -t=s: String parameters
#   -t=i: Number paramters
##---------------------------------------------------------------------------##

my $hmm           = "";
my $db            = "";
my $help          = "";
my $hmmer_options = "";
my $tax_dist_file = '';
my $hmmer_result  = "";
my $run_hmm       = 0;
my $cutoff1;
my $cutoff2;
my $clean       = 0;
my $result_file = "";
my $add         = 0;
my @hit_list;

my %taxonomy_list;
my $tmpfile;

#
# Get the supplied command line options, and set flags
#

GetOptions( 'help'        => \$help,
			'file|f=s'    => \$hmm,
			#'db|d=s'      => \$db,
			#'options|o=s' => \$hmmer_options,
			'taxdist|t=s' => \$tax_dist_file,
			'result|r=s'  => \$result_file,
			'score|s=s'  => \$cutoff1,
			'e-value|e=s' => \$cutoff2,
			#'clean'       => \$clean,
			#'hmmer|H=s'   => \$hmmer_result,
			'add|a'       => \$add,
) or pod2usage( -verbose => 1 );

pod2usage( -verbose => 2 ) if $help;

open (FILE, $hmm) || die "Can't open $hmm\n";
while (my $line = <FILE>) {
	next if ($line =~ /^\#/);
	chomp $line;
	my @f = split (/\t/, $line);
	die "Improper BLAST format" unless (@f == 12);
	if ($cutoff1) {
		next unless ($f[11] >= $cutoff1);
	} 
	if ($cutoff2) {
		next unless ($f[10] <= $cutoff2);
	}
	push @hit_list, $f[1];
}
close (FILE);

#if ($add) {
#	check_params( $result_file, $tax_dist_file );
#	parse_file($result_file);
#	add_taxa();
#	print_result();
#	exit(0);
#}



find_taxa();

if ($tax_dist_file) {
	check_params($tax_dist_file);
	add_taxa();
}

print_result();



sub find_taxa {
	my $max = scalar(@hit_list);
	print STDERR "Found $max hits.\n";
	my $progress1 =
		Term::ProgressBar->new( { name   => 'Finding taxa',
								  count  => $max,
								  remove => 1,
								  ETA    => 'linear'
								}
		);
	$progress1->max_update_rate(1);
	$progress1->minor(0);

	my $count        = 0;
	my $next_update1 = 0;

	my $taxonomy = SeqToolBox::Taxonomy->new();

	foreach my $gi (@hit_list) {

		my $taxon = $taxonomy->get_taxon($gi);

		#	print STDERR "$gi\t$taxon\n";
		if ($taxon) {
			$taxonomy_list{$taxon} = 1;
		}
		$count++;
		$next_update1 = $progress1->update($count)
			if $count >= $next_update1;
	}
}

sub print_result {

	foreach my $key ( sort { $a <=> $b } keys %taxonomy_list ) {
		print $key , "\t", $taxonomy_list{$key}, "\n";
	}

}




sub check_params {
	my @args = @_;

	foreach my $p (@args) {
		unless ($p) {
			pod2usage( -verbose => 1 );
		}

		unless ( -s $p ) {
			croak "$p does not exists\n";
		}
	}
}


sub add_taxa {

	if ($tax_dist_file) {
		print STDERR "Adding taxa from taxon distribution file...";
		open( FILE, $tax_dist_file ) || die "Can't open $tax_dist_file\n";

		while ( my $line = <FILE> ) {
			chomp $line;

			unless ( exists $taxonomy_list{$line} ) {
				$taxonomy_list{$line} = 0;
			}
		}
		close(FILE);
		print STDERR "done.\n";

	} else {
		croak "$tax_dist_file not found\n";
	}
}
exit(0);

__END__

=head1 NAME

blast2profile.pl - Creating a phylogenetic profile out of a BLAST result in -m9/-m8 format.

=head1 SYNOPSIS

blast2profile.pl [options] > result_file


=head1 DESCRIPTION

The script parses a BLAST result file in -m9/-m8 format and creates a phylogenetic profile suitable for use with ppp.pl.

=head1 INSTALLATION

You need Malay's SeqToolBox to run this script. Contact Malay (mbasu@jcvi.org) for a copy of SeqToolBox. Unzip the modules in your PERL5LIB. You need to first set up the NCBI taxonomy database for using this script. For this set up an environment variable "SEQTOOLBOXDB" pointing to a directory that can store about ~1.5 GB of data. After setting up this enviornment variable, run install/update_taxonomy.pl script. This will create all the databases required for running this script. If you are using this as a part of ProPhylo package then follow the installation instruction of ProPhylo. Nothing special is needed.

=head1 OPTIONS 

=over 4

=item B<--help | -h>

Print this help message.

=item B<--file | -f>

The full path of BLAST result file.


=item B<--taxdis | -t = taxonomic_distribution_file>

A taxnomic distribution file. Should have been created using taxdist_fasta.pl. These taxons are appended to the final profile files, after checking the presence or absence of hits in these taxa. 


=item B<--score | -s = bit_score_cutoff>

Bit score cutoff for the blast result file. Taxonomic group higher or equal to this cutoff will be marked 1 in the resulting profile.

=item B<--e-value | -e = e-value cutoff>

E-value cutoff for the blast result file. The taxonomic group lower than or equal to this cutoff will be marked 1 in the resulting profile.

=back



=head1 COPYRIGHT

Copyright (c) 2011 Malay K Basu <malay@bioinformatics.org>.

=head1 AUTHORS

Malay K Basu <malay@bioinformatics.org>

=cut
