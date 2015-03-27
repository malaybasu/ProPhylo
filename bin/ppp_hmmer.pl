#!/usr/local/bin/perl
# $Id: ppp_hmmer.pl 658 2011-07-28 18:54:29Z malay $

##---------------------------------------------------------------------------##
##  File: ppp_hmmer.pl
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

ppp_hmmer.pl - This is a PPP scoring program using HMMER result, instead of BLAST.

=head1 SYNOPSIS

ppp.pl [options] -p profile -h hmmer_result > result


=head1 DESCRIPTION

The software takes a profile file and a hmmer result file as an argument. It shows the best scoring hit on hmmer file using PPP algorithm. And also create a list of positive GIs.


=head1 MANDETORY OPTIONS


=over 4

=item B<-p | --profile <file>>

A profile file with format as shown below:

 tax_id 1
 tax_id 0
...

This profile file will be searched against the database.


=item B<-h | hmmer_result <hmmer_result_file>>

A HMMER3 result file.


=back

=head1 OTHER OPTIONS

=over 4

=item B<-h | --help>

Print this help page.

=over 4

=item B<--prob probablity>

A value <1 and >0 for use as probablity in PPP alogrithm.

=back

=head1 COPYRIGHT

Copyright (c) 2009 Malay K Basu

=head1 AUTHORS

Malay K Basu <mbasu@jcvi.org>

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
use PhyloProf::Profile;
use PhyloProf::Algorithm::ppp;
use DBI;
use POSIX ":sys_wait_h";
use File::Temp;
use File::Path;

#use PhyloProf::DB::CMR;
use PhyloProf::HMMERResult;
use Cwd;

########## Requirement checks ################
unless ( $ENV{'SEQTOOLBOXDB'} ) {
	croak "SEQTOOLBOXDB not defined\n";
}

#print STDERR "PERL5LIB ", $ENV{PERL5LIB}, "\n";
eval { require SeqToolBox::Taxonomy };

if ($@) {
	croak
		"This script requires Malay's toolbox. Contact him at mbasu\@jcvi.org.\n";
}

eval { require SeqToolBox::HMMER::Parser };

if ($@) {
	croak
		"This script requires Malay's toolbox. Contact him at mbasu\@jcvi.org.\n";
}

eval { require PhyloProf::Profile };
if ($@) {
	croak "This scrip requires Phyloprof::Profile\n";
}
##############################################

my $db_dir    = '/usr/local/archive/projects/PPP/split_genomes';
my $client    = 0;
my $workspace = cwd();
my $taxon;
my $profile;
my $level   = '';
my $SGE     = "qsub -b y -j y -V";
my $project = "0380";
my $nodes   = 10;
my $help;
my $copy;

#my $file;
my $program_name = File::Spec->catfile( $FindBin::Bin, 'ppp_grid.pl' );
my $blast        = "";
my $genome_dir   = "";
my $blastdb      = "";
my $output       = "";
my $NP           = 500;
my $LSF          = "qsub";
my $LSF_OPTIONS  = "-b y -j y -V -P 0380";
my $engine       = "SGE";
my $SGE_version  = 5;
my $probability  = 0;
my $serial       = 0;
my $threads      = 1;
my $grid;
my $dummy_gi;
my $dummy_start;
my $dummy_end;
my $dummy_skip;
my $slope = undef;
my $keep_files;
my $hmmer_result;
my $trusted_cutoff;
my $domain;

GetOptions( 'help|h'             => \$help,
			'profile|p=s'        => \$profile,
			'hmmer_result|hmm=s' => \$hmmer_result,
			'level|l=s'          => \$level,
			'trusted_cutoff|t=s' => \$trusted_cutoff,
			'prob=s'             => \$probability,
			'domain'             => \$domain,
) or pod2usage( -verbose => 1 );

pod2usage( -verbose => 2 ) if $help;

die "HMMER file not give" unless -s $hmmer_result;

my $taxonomy = SeqToolBox::Taxonomy->new();

my $ref_profile;

if ($level) {

	$ref_profile =
		PhyloProf::Profile->new( -file     => $profile,
								 -rank     => $level,
								 -taxonomy => $taxonomy
		);
} else {
	$ref_profile =
		PhyloProf::Profile->new( -file     => $profile,
								 -taxonomy => $taxonomy );
}

my $hmmer_result_obj = SeqToolBox::HMMER::Parser->new( $hmmer_result, 3 );
croak "Could not created hmmer obj for $hmmer_result" unless $hmmer_result_obj;

my ( $blast_profile, $hmmer_hits, $hmmer_full );

if ($domain) {
	( $blast_profile, $hmmer_hits, $hmmer_full )
		= get_profile_by_domain($hmmer_result_obj);

} else {
	( $blast_profile, $hmmer_hits, $hmmer_full )
		= get_profile($hmmer_result_obj);
}
my @param = ( "-prof1" => $ref_profile, "-prof2" => $blast_profile );

if ( $probability > 0 ) {
	push @param, "-prob", $probability;
}

if ($level) {
	push @param, "-rank", $level;
}

my $alg = PhyloProf::Algorithm::ppp->new(@param);
$alg->{_dbh} = $taxonomy;

my ( $score, $yes, $number, $depth, $p ) = $alg->get_match_score();
print "Score\t#yes\t#Toal\t#Depth\t#Prob\n";
my $log_score = sprintf( "%.3f", log($score) / log(10) );
my $prob      = sprintf( "%.2f", $p );
print "$log_score\t$yes\t$number\t$depth\t$prob\n";

my @positive_gi;

my %seen;

for ( my $i = 0; $i < $depth; $i++ ) {

	#	my @line;
	my $taxon = $taxonomy->get_taxon( $hmmer_hits->[$i] );
	my $yes   = 'N';

	if ( $ref_profile->is_yes($taxon) ) {

		#		push @positive_gi,
		#			$hmmer_hits->[$i] . "\t" . $hmmer_full->{ $hmmer_hits->[$i] };
		$yes = 'Y';
	}
	my $desc  = $hmmer_result_obj->get_desc( $hmmer_hits->[$i] );
	my $score = $hmmer_full->{ $hmmer_hits->[$i] };
	my $line  = join( "\t", $taxon, $hmmer_hits->[$i], $yes, $score, $desc );
	push @positive_gi, $line;
}
print "Taxon\tGI\tPositive\tHMMER_score\tDesc\n";
print join( "\n", @positive_gi );
print "\n";

sub get_profile_by_domain {
	my $hmmer_result_obj = shift;

	my @hmmer_hits;

	if ($trusted_cutoff) {
		@hmmer_hits
			= $hmmer_result_obj->get_above_cutoff_domain_h3($trusted_cutoff);

	} else {
		@hmmer_hits = $hmmer_result_obj->get_above_cutoff_domain_h3(0);
	}

	my $hmmer_full_data = $hmmer_result_obj->get_h3domain_hash();

	my $hmmer =
		PhyloProf::HMMERResult->new( -data   => \@hmmer_hits,
									 -value  => "score",
									 -sorted => 1,
		);
	return $hmmer->get_profile(), \@hmmer_hits, $hmmer_full_data;

}

sub get_profile {
	my $hmmer_result_obj = shift;

	my @hmmer_hits;

	if ($trusted_cutoff) {
		@hmmer_hits = $hmmer_result_obj->get_above_cutoff_h3($trusted_cutoff);

	} else {
		@hmmer_hits = $hmmer_result_obj->get_above_cutoff_h3(0);
	}

	my $hmmer_full_data = $hmmer_result_obj->get_h3_data_as_hash();

	my $hmmer =
		PhyloProf::HMMERResult->new( -data   => \@hmmer_hits,
									 -value  => "score",
									 -sorted => 1,
		);
	return $hmmer->get_profile(), \@hmmer_hits, $hmmer_full_data;

}

exit(0);
