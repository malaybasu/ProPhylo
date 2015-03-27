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
			'db|d=s'      => \$db,
			'options|o=s' => \$hmmer_options,
			'taxdist|t=s' => \$tax_dist_file,
			'result|r=s'  => \$result_file,
			'cutoff1|c1=s'  => \$cutoff1,
			'cutoff2|c2=s' => \$cutoff2,
			'clean'       => \$clean,
			'hmmer|H=s'   => \$hmmer_result,
			'add|a'       => \$add,
) or pod2usage( -verbose => 1 );

pod2usage( -verbose => 2 ) if $help;

if ($hmm) {
	croak "Run hmm has been disabled for the time being";
	$run_hmm = 1;
}

if ( $add && $run_hmm ) {
	croak "-A can not be used with -f\n";
}

if ($add) {
	check_params( $result_file, $tax_dist_file );
	parse_file($result_file);
	add_taxa();
	print_result();
	exit(0);
}

if ($run_hmm) {
	check_params( $db, $hmm );
	run_hmm();
} else {
	check_params($hmmer_result);
	print STDERR "Parsing HMMSEARCH result...";
	@hit_list = parse_hmmsearch($hmmer_result);
	print STDERR "done.\n";
}

find_taxa();

if ($tax_dist_file) {
	check_params($tax_dist_file);
	add_taxa();
}

print_result();

if ( $clean && $tmpfile ) {

	system("rm $tmpfile") == 0 or print STDERR "Could not remove $tmpfile\n";

}

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

sub parse_file {
	my $file = shift;
	open( my $infile, $file ) || die "Can't open $file\n";

	while ( my $line = <$infile> ) {
		chomp $line;
		my (@f) = split( /\t/, $line );

		if ( @f != 2 ) {
			croak "Error in parsing $file\n";
		}
		$taxonomy_list{ $f[0] } = $f[1];
	}
	close($infile);
}

sub run_hmm {
	print STDERR "Running HMMSEARCH...";
	my $hmmsearch = 'hmmsearch';
	my $tmpfile = File::Temp->new( UNLINK   => 0,
								   SUFFIX   => '.tmp',
								   TEMPLATE => 'hmmer_XXXXX',
								   DIR      => cwd()
	);

	#	$tmpfile = "hmm2profile". $tmp;

	if ($hmmer_options) {
		$hmmsearch .= " $hmmer_options";

	}

	my $command = "$hmmsearch $hmm $db";

	#print STDERR $command, "\n";
	system("$command >$tmpfile") == 0
		or croak "Could not run HMMSEARCH";

	print STDERR "done.\n";

	print STDERR "Parsing HMMSEARCH result...";
	@hit_list = parse_hmmsearch($tmpfile);
	print STDERR "done.\n";
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

sub parse_hmmsearch {

	my $file = shift;

	#	print STDERR $cutoff, "\n";
	my @result;

	#my $in = Bio::SearchIO->new( -format => 'hmmer', -file => $file );

	#	while ( my $result = $in->next_result ) {
	#		while ( my $hit = $result->next_hit ) {
	#
	#			#			print STDERR $hit->name();
	#			if ( $cutoff) {
##				print STDERR $cutoff, "\t", $hit->raw_score(), "\n";
	#				if ( $cutoff <= $hit->raw_score ) {
	#					push @result, $hit->name();
	#				}
	#			}
	#			else {
	#				push @result, $hit->name();
	#			}
	#		}
	#	}
	my $in = SeqToolBox::HMMER::Parser->new( $file, 3 );
	if (!$cutoff1 && !$cutoff2) {
		my $data = $in->get_h3_data_as_hash();
		foreach my $t ( keys %{$data} ) {
			push @result, $t;
		}
	}elsif ($cutoff1 && !$cutoff2) {
		my $data = $in->get_h3_data_as_hash();
		foreach my $t ( keys %{$data} ) {
			if ( $cutoff1 <= $data->{$t} ) {
				push @result, $t;
			}
		}
	}elsif ($cutoff2 && !$cutoff1) {
		my $data = $in->get_h3domain_hash();
		foreach my $t (keys %{$data}) {
			if ($cutoff2 <= $data->{$t}) {
				push @result, $t;
			}
		}
	}elsif ($cutoff1 && $cutoff2) {
#		print STDERR "both defined\n";
		@result = $in->get_above_cutoff_t1_t2(3, $cutoff1, $cutoff2);
		
	}
	

	

		#		print STDERR $t,"\t", $data->{$t}, "\n";
	

		#		if ($cutoff && $cutoff <= $data->{$t}) {
		#			push @result, $t;
		#		}elsif ($cutoff) {
		#			push @result, $t;
		#		}
	

	#@result = keys(%{$data});
	return @result;
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

hmm3profile.pl - Creating a phylogenetic profile out of a HMMSEARCH result from HMMR3.

=head1 SYNOPSIS

hmm3profile.pl [options] > result_file


=head1 DESCRIPTION

This script search a fasta database of sequences by a HMM. It then parses the resulting file to create a phylogenetic profile. 

=head1 INSTALLATION

You need Malay's SeqToolBox to run this script. Contact Malay (mbasu@jcvi.org) for a copy of SeqToolBox. Unzip the modules in your PERL5LIB. You need to first set up the NCBI taxonomy database for using this script. For this set up an environment variable "SEQTOOLBOXDB" pointing to a directory that can store about ~1.5 GB of data. After setting up this enviornment variable, run install/update_taxonomy.pl script. This will create all the databases required for running this script. If you are using this as a part of ProPhylo package then follow the installation instruction of ProPhylo. Nothing special is needed.

=head1 OPTIONS 

=over 4

=item B<--help | -h>

Print this help message.

=item B<--file | -f>

The full path of HMM file.

=item B<--db | -d>

The multifasta file containing the sequences.

=item B<--options| -o>

Options directly passed through HMMSEARCH. Pass this as complete string like this "-E 0.001 --threads 4". Keep the quote around the options.

=item B<--taxdis | -t>

A taxnomic distribution file. Should have been created using taxdist_fasta.pl. These taxons are appended to the final profile files, after checking the presence or absence of hits in these taxa. 

=item B<--hmmer | -H = hmmer_result_file>

You can create a profile out of a pre-existing HMMER search. You can not use both -f,-H, or -a at the same time.

=item B<--add | -a>

You can add taxon data to a pre-existing result. Use -t with this option.

=item B<--clean>

Clean the HMMER result file.

=item B<--cutoff1 | -c1 = bit_score_cutoff1>

You can use a bit score cutoff for the whole protein while parsing a preexisting HMMER result file.

=item B<--coutoff2 | -c2 = bit_score_cutoff2>

You can use bit score cutoff for the domain score while parsing a preexisting HMMER result.

=back



=head1 COPYRIGHT

Copyright (c) 2009 Malay K Basu <malay@bioinformatics.org>.

=head1 AUTHORS

Malay K Basu <malay@bioinformatics.org>

=cut
