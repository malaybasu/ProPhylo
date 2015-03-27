#!/usr/local/bin/perl
# $Id: ppp_cross_score.pl 736 2014-07-28 18:01:56Z malay $

##---------------------------------------------------------------------------##
##  File: ppp_cross_score.pl
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

ppp_cross_score.pl - Given two search results (HMMER3 or BLAST), the script evaluates the best depth of the PPP score of one result to the other.

=head1 SYNOPSIS

ppp_corss_score.pl -f1 <search_result1> -f2 <search_result_2> -m1 <method for 1> -m2 <method for 2> 


=head1 DESCRIPTION

The software takes two search result files either in BLAST -m 8 or -m 9 format or in HMMER3 format. Any of the files can be in any of these two formats. The software creats profiles for each depth of one file and searches each of these profiles against the other file using PPP algorithm. At the end the software report the best score of PPP and the depth at which the score was found in each of these files.

=head1 MANDETORY OPTIONS


=over 4

=item B<--file1 | -f1 <FILE>>

The first search result file, either in BLAST or HMMER format.

=item B<--file2 | -f2 <FILE> >

The second result file, either in BLAST or HMMER format.


=item B<--method1 | -m1 blast/hmmer >

The search method used to generate the first file. Can be either "blast" or "hmmer".


=item B<--method2 | -m2 blast/hmmer >

The search method used to generate the second file. Can be either "blast" or "hmmer".



=back

=head1 OTHER OPTIONS

=over 4


=item B<-l | --level taxonomic_level>

The taxonomic level that should be searched; family, genus, species, etc. Any taxonomic rank as understood by NCBI taxonomy database can be used. The default is to do the search as taxon id level. 

=item B<--prob probability>

This is the probabliity for the PPP algorithm. The default is to calculate the probablity from the the given profile.

=item B<-s | --start-depth number>

Start the iteration after this many taxon have reached. There is no point searching the binomial probability with very few taxonomic group. Default 5.

=item B<-e | --end-depth number>

Stop the iteration after this many taxonomic group has been found. By default the algorithm ends at the end of the blast result file.

=item B<-j | --skip number>

This parameter allows the iteration to skip lines of the source blast result. By default the algorithm searches every blast hit. Set it to a number highter than one and your searches will be faster but may be inaccurate.

=item B<--trusted_cutoff | -t <number>>

The trusted cutoff value to be used to filter hmmer results.

=item B<-h | --help>
Print this help page.

=item B<--keep | -k >

If given, keep the temporary files under directory 'tmp~'.

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
use File::Path;
use SeqToolBox;
use SeqToolBox::HMMER::Parser;
use PhyloProf::HMMERResult;

#use PhyloProf::DB::CMR;
use PhyloProf::BlastResult;
use Cwd;
use Data::Dumper;
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

eval { require PhyloProf::Profile };
if ($@) {
	croak "This script requires Phyloprof::Profile\n";
}
##############################################

#my $db_dir    = '/usr/local/archive/projects/PPP/split_genomes';
#my $client    = 0;
my $workspace = cwd();

#my $taxon;
#my $profile;
my $level = '';

#my $SGE     = "qsub -b y -j y -V";
#my $project = "0380";
#my $nodes   = 10;
my $help;

#my $copy;
#my $file;
#my $program_name = File::Spec->catfile( $FindBin::Bin, 'ppp_grid.pl' );
#my $blast        = "";
#my $genome_dir   = "";
#my $blastdb      = "";
#my $output       = "";
#my $NP           = 500;
#my $LSF          = "qsub";
#my $LSF_OPTIONS  = "-b y -j y -V -P 0380";
#my $engine       = "SGE";
#my $SGE_version  = 5;
my $probability = 0;

#my $serial       = 0;
my $threads = 1;

#my $grid;
#my $gi    = "";
my $start = 1;
my $end;

#my $total_taxa_count = 1459;
my $skip = 1;

my $keep_files;

#my $duplicate;
my $file1;
my $file2;
my $method1;
my $method2;
my $taxonomy = SeqToolBox::Taxonomy->new();
my $best_score;
my %score;
my $trusted_cutoff = 0;
my $dist_file;
my $total_number_of_taxa;
my $scale = 1;
my $best_score_gi;
#print STDERR $program_name;

#
# Get the supplied command line options, and set flags
#
my @argv = @ARGV;

#print STDERR "Before getoptions\n";
GetOptions(
	'help|h'       => \$help,
	'file1|f1=s'   => \$file1,
	'file2|f2=s'   => \$file2,
	'method1|m1=s' => \$method1,
	'method2|m2=s' => \$method2,

	#	'db|d=s'          => \$db_dir,
	'workspace|w=s' => \$workspace,

	#	'taxon|t=i'       => \$taxon,
	#	'profile|p=s'     => \$profile,
	'level|l=s' => \$level,

	#	'project|r=i'     => \$project,
	#	'nodes|n=i'       => \$nodes,
	#	'client'          => \$client,
	#	'copy|c'          => \$copy,
	#	'output|o=s'      => \$output,
	'prob=s'             => \$probability,
	'trusted_cutoff|t=s' => \$trusted_cutoff,

	#	'serial'          => \$serial,
	'threads=i' => \$threads,

	#	'gi|g=i'          => \$gi,
	'start-depth|s=i' => \$start,
	'end-depth|e=i'   => \$end,
	'skip|j=i'        => \$skip,

	'keep|k' => \$keep_files,

	#	'dup'             => \$duplicate,

	#			'blast|b'		=> \$blast,
	#			'genome|g=s'	=> \$genome_dir,
	#			'blastdb'	=>\$blastdb,
	'dist-file|d=s' => \$dist_file,    # Phylogenetic distribution file;
	'scale=s'       => \$scale         # A scale factor for probability
) or pod2usage( -verbose => 1 );

pod2usage( -verbose => 2 ) if $help;

unless ( $file1 && $file2 && $method1 && $method2 && $dist_file ) {
	die pod2usage( -verbose => 2 );
}

if ( $method1 !~ /^(blast|hmmer)$/i || $method2 !~ /^(blast|hmmer)$/i ) {
	print STDERR "Method can be only BLAST or HMMER\n";
}

my $tmp_dir   = get_temp_dir_name();
my $ppp_dir   = File::Spec->catdir( $tmp_dir, 'ppp' );
my $total_job = 0;
my @jobs;

#my %pid_2_filename;
#my %time;
#my @excluded_machines;
my $phylo_prof_bin = File::Spec->catfile( $FindBin::Bin, "ppp.pl" );

main();

sub main {
	my $number_of_taxa = get_number_of_taxa($dist_file);
	die "Could not determine number of taxa" unless $number_of_taxa;
	$total_number_of_taxa = $number_of_taxa;
	my $target_profile1 = get_target_profile( $file2, $method2 );

	#	print Dumper($target_profile1);
	my $target_profile2 = get_target_profile( $file1, $method1 );

	#	print Dumper ($target_profile2);
	_evaluate( $file1, $method1, $target_profile1 );
	print "File1: $file1 Best result in $file2:\n";
	print "Source_Line:gi\tScore\t#yes\t#Total\t#Depth\t#Prob\n";
	print $best_score->{$file1}, ":",$best_score_gi,"\t",
	  join( "\t", @{ $score{$file1}->{ $best_score->{$file1} } } ), "\n\n";
	  _evaluate( $file2, $method2, $target_profile2 );
	print "File2: $file2 Best result in $file1:\n";
	print "Source_Line:gi\tScore\t#yes\t#Toal\t#Depth\t#Prob\n";
	print $best_score->{$file2},':',$best_score_gi,"\t",
	  join( "\t", @{ $score{$file2}->{ $best_score->{$file2} } } ), "\n";

	unless ($keep_files) {
		system("rm -rf $tmp_dir") == 0 or die "Could not remove $tmp_dir\n";
	}
}

sub get_number_of_taxa {
	my $file = shift;

	#	print STDERR $file;
	open( FILE, $file ) || die "Can't open $dist_file\n";
	my $count = 0;
	while ( my $line = <FILE> ) {
		next if ( $line =~ /^\#/ );
		$count++;
	}
	close(FILE);
	return $count;
}

sub get_target_profile {
	my ( $file, $method ) = @_;

	#print STDERR "targ profile called\n";
	if ( $method =~ /blast/i ) {
		return get_target_profile_blast($file);
	} elsif ( $method =~ /hmmer/i ) {
		return get_target_profile_hmmer($file);
	} else {
		croak "Could not understand format option $method\n";
	}
}

sub get_target_profile_hmmer {
	my $file = shift;
	my $hmmer_result_obj = SeqToolBox::HMMER::Parser->new( $file, 3 );
	croak "Could not created hmmer obj for $file" unless $hmmer_result_obj;

	my @hmmer_hits;
	if ($trusted_cutoff) {
		@hmmer_hits
		  = $hmmer_result_obj->get_above_cutoff_domain_h3($trusted_cutoff);

	} else {
		@hmmer_hits = $hmmer_result_obj->get_above_cutoff_domain_h3(0);
	}

	my $hmmer =
	  PhyloProf::HMMERResult->new(
								   -data   => \@hmmer_hits,
								   -value  => "score",
								   -sorted => 1,
	  );
	return $hmmer->get_profile();

}

sub get_target_profile_blast {
	my $file_name = shift;
	open( my $blast_file, $file_name ) or die "Can't open $file_name\n";
	my %data;
	my @values;
	my %subject_taxon_class;

	while ( my $line = <$blast_file> ) {
		next if $line =~ /^\#/;
		chomp $line;
		my @f = split( /\t/, $line );

		if ( @f != 12 ) {
			die
			  "Wrong BLAST result format. You should run BLAST with -m 8/9\n";
		}
		my $gi;

		if ( $f[1] =~ /gi\|(\d+)/ ) {
			$gi = $1;
		}
		die "Could not parse gi from file\n" unless $gi;
		my $taxon = $taxonomy->get_taxon($gi);

		unless ($taxon) {
			print STDERR "Could not find taxon for $gi\n";
			next;
		}

		if ( exists $data{ $f[11] } ) {
			if ( $data{ $f[1] } < $f[11] ) {
				$data{ $f[1] } = $f[11];
			}
		} else {
			$data{ $f[1] } = $f[11];
			push @values, $f[1];
		}

		$subject_taxon_class{ $f[1] } = $taxon;
	}

	#print STDERR "BLAST data\n";

	#	foreach my $i ( keys %data ) {
	#		print $i, "\t", $data{$i}, "\n";
	#	}
	close($blast_file);

	#	my $blast =
	#		PhyloProf::BlastResult->new( -data     => \%data,
	#									 -value    => "e-value",
	#									 -taxonomy => \%subject_taxon_class
	#		);

	my $blast =
	  PhyloProf::BlastResult->new(
								   -data     => \@values,
								   -value    => "e-value",
								   -sorted   => 1,
								   -taxonomy => \%subject_taxon_class
	  );
	return $blast->get_profile();

}

sub _evaluate {
	my ( $file, $method, $target_profile ) = @_;
	croak "Can't locate $file\n" unless ( -s $file );

	if ( $method =~ /hmmer/i ) {
		return _evaluate_hmmer(@_);
	}

	open( my $input_file, $file ) or die "Can't open $file\n";
	my %data;
	my %subject_taxon_class;
	my $line_count = 0;
	my %result_score;
	my %result_data;
	$best_score_gi = "";

	if ( $method =~ /blast/i ) {
		while ( my $line = <$input_file> ) {
			next if $line =~ /^\#/;
			chomp $line;
			next unless $line;
			++$line_count;
			my @f = split( /\t/, $line );

			if ( @f != 12 ) {
				die
"Wrong BLAST result format. You should run BLAST with -m 8/9\n";
			}

			if ( exists $data{ $f[11] } ) {
				if ( $data{ $f[1] } < $f[11] ) {
					$data{ $f[1] } = $f[11];
				}
			} else {
				$data{ $f[1] } = $f[11];
			}
			my $gi;

			if ( $f[1] =~ /gi\|(\d+)/ ) {
				$gi = $1;
			}
			die "Could not parse gi from file\n" unless $gi;
			my $taxon = $taxonomy->get_taxon($gi);

			unless ($taxon) {
				print STDERR "Could not find taxon for $gi\n";
				next;
			}
			next if ( exists $subject_taxon_class{$taxon} );
			$subject_taxon_class{$taxon} = 1;
			next if ( $line_count % $skip );
			my $taxon_count = scalar( keys %subject_taxon_class );
			last if ( $end && $taxon_count > $end );

			if ( $taxon_count >= $start ) {
				my $outfile_name
				  = $file
				  . '_input_porfile_'
				  . $line_count . '_'
				  . $taxon_count . '_'
				  . $gi . '.prof';
				my $outpath = File::Spec->catfile( $tmp_dir, $outfile_name );
				open( my $outhandle, ">$outpath" )
				  || die "Can't open $outpath\n";

				foreach my $t ( keys %subject_taxon_class ) {
					print $outhandle $t, "\t", 1, "\n";
				}
				close($outhandle) ;
				my $ref_profile;

				if ($level) {

					$ref_profile =
					  PhyloProf::Profile->new(
											   -file     => $outpath,
											   -rank     => $level,
											   -taxonomy => $taxonomy
					  );
				} else {
					$ref_profile =
					  PhyloProf::Profile->new( -file     => $outpath,
											   -taxonomy => $taxonomy );
				}
				my $pr = $line_count / $total_number_of_taxa;
				if ($scale) {
					$pr = $pr * $scale;
				}

				#print Dumper ($ref_profile);
				my ( $score, $yes, $number, $depth, $p )
				  = get_ppp_score( $ref_profile, $target_profile, $pr );

			   #				_write_score ($ref_profile, $target_profile, $line_count);

				#				print "Score\t#yes\t#Toal\t#Depth\t#Prob\n";
				my $log_score = sprintf( "%.3f", log($score) / log(10) );
				my $prob      = sprintf( "%.2f", $p );
				my @array = ( $log_score, $yes, $number, $depth, $prob );

				#print STDERR "@array", "\n";
				$score{$file}->{"$line_count"} = \@array;

				if (
					exists $best_score->{$file}

		  #					 && ${$score{$file}->{$best_score->{$file}}}->[0] < $log_score
				  )
				{

					#					print STDERR $score{$file};
					my @array = @{ $score{$file}->{ $best_score->{$file} } };
					my $high_score = $array[0];

					#					print STDERR "High score: $high_score\n";
					if ( $high_score > $log_score ) {
						$best_score->{$file} = $line_count;
						$best_score_gi = $gi;
					}

				} elsif ( !exists $best_score->{$file} ) {
					$best_score->{$file} = $line_count;
					$best_score_gi = $gi;
				}

				#print "$log_score\t$yes\t$number\t$depth\t$prob\n";
			}
		}

		#		print Dumper($best_score);
	}
}


sub _evaluate_hmmer {
	my ( $file, $method, $target_profile ) = @_;
	my $hmmer_result_obj = SeqToolBox::HMMER::Parser->new( $file, 3 );
	croak "Could not created hmmer obj for $file" unless $hmmer_result_obj;

	my @hmmer_hits;
	if ($trusted_cutoff) {
		@hmmer_hits
		  = $hmmer_result_obj->get_above_cutoff_domain_h3($trusted_cutoff);

	} else {
		@hmmer_hits = $hmmer_result_obj->get_above_cutoff_domain_h3(0);
	}
	my $line_count = 0;
	my %subject_taxon_class;
	foreach my $hit (@hmmer_hits) {

		#			next if $line =~ /^\#/;
		#			chomp $line;
		#			next unless $line;
		++$line_count;

		#			my @f = split( /\t/, $line );

		#			if ( @f != 12 ) {
		#				die
		#					"Wrong BLAST result format. You should run BLAST with -m 8/9\n";
		#			}

		#			if ( exists $data{ $f[11] } ) {
		#				if ( $data{ $f[1] } < $f[11] ) {
		#					$data{ $f[1] } = $f[11];
		#				}
		#			} else {
		#				$data{ $f[1] } = $f[11];
		#			}
		my $gi;

		if ( $hit =~ /gi\|(\d+)/ ) {
			$gi = $1;
		}
		die "Could not parse gi from file\n" unless $gi;
		my $taxon = $taxonomy->get_taxon($gi);

		unless ($taxon) {
			print STDERR "Could not find taxon for $gi\n";
			next;
		}
		next if ( exists $subject_taxon_class{$taxon} );
		$subject_taxon_class{$taxon} = 1;
		next if ( $line_count % $skip );
		my $taxon_count = scalar( keys %subject_taxon_class );
		last if ( $end && $taxon_count > $end );

		if ( $taxon_count >= $start ) {
			my $outfile_name
			  = $file
			  . '_input_porfile_'
			  . $line_count . '_'
			  . $taxon_count . '.prof';
			my $outpath = File::Spec->catfile( $tmp_dir, $outfile_name );
			open( my $outhandle, ">$outpath" )
			  || die "Can't open $outpath\n";

			foreach my $t ( keys %subject_taxon_class ) {
				print $outhandle $t, "\t", 1, "\n";
			}
			close($outhandle);
			my $ref_profile;

			if ($level) {

				$ref_profile =
				  PhyloProf::Profile->new(
										   -file     => $outpath,
										   -rank     => $level,
										   -taxonomy => $taxonomy
				  );
			} else {
				$ref_profile =
				  PhyloProf::Profile->new( -file     => $outpath,
										   -taxonomy => $taxonomy );
			}
			my $pr = $line_count / $total_number_of_taxa;
			if ($scale) {
				$pr = $pr * $scale;
			}
			my ( $score, $yes, $number, $depth, $p )
			  = get_ppp_score( $ref_profile, $target_profile, $pr );

			#				_write_score ($ref_profile, $target_profile, $line_count);

			#print "Score\t#yes\t#Toal\t#Depth\t#Prob\n";
			my $log_score = sprintf( "%.3f", log($score) / log(10) );
			my $prob      = sprintf( "%.2f", $p );
			my @array = ( $log_score, $yes, $number, $depth, $prob );

			#print STDERR "@array", "\n";
			$score{$file}->{"$line_count"} = \@array;

			if (
				exists $best_score->{$file}

		  #					 && ${$score{$file}->{$best_score->{$file}}}->[0] < $log_score
			  )
			{

				#					print STDERR $score{$file};
				my @array      = @{ $score{$file}->{ $best_score->{$file} } };
				my $high_score = $array[0];

				#					print STDERR "High score: $high_score\n";
				if ( $high_score > $log_score ) {
					$best_score->{$file} = $line_count;
				}

				#
				#			if ( exists $best_score->{$file}
				#				 && $best_score->{$file} < $log_score )
				#			{
				#				$best_score->{$file} = $line_count;

			} elsif ( !exists $best_score->{$file} ) {
				$best_score->{$file} = $line_count;

			}

			#print "$log_score\t$yes\t$number\t$depth\t$prob\n";
		}
	}
}

sub get_ppp_score {
	my ( $ref_profile, $target_profile, $probability ) = @_;
	my @param = ( "-prof1" => $ref_profile, "-prof2" => $target_profile );

	if ( $probability > 0 ) {
		push @param, "-prob", $probability;
	} else {
		die "Error in calculating probability\n";
	}

	if ($level) {
		push @param, "-rank", $level;
	}
	my $alg = PhyloProf::Algorithm::ppp->new(@param);

	#print Dumper($alg);
	$alg->{_dbh} = $taxonomy;
	return $alg->get_match_score();
}

#my $blast_result_file
#	= File::Spec->catfile( $db_dir, "blast", $input_taxonomy, $gi_file_name );

#read_tax_dis_file();

#while ( my $line = <$blast_file> ) {
#
#	chomp $line;
#	++$line_count;
#
#	my @f = split( /\t/, $line );
#	if ( $f[0] eq $f[1] ) {
#		$subject_taxon_class{ $f[3] } = 1;
#		next;
#	}
#
#	if ( exists $data{ $f[1] } ) {
#		if ( $data{ $f[1] } > $f[2] ) {
#			$data{ $f[1] } = $f[2];
#		}
#	} else {
#		$data{ $f[1] } = $f[2];
#	}
#
#	if ( exists $subject_taxon_class{ $f[3] } ) {
#		next;
#	}
#
#	$subject_taxon_class{ $f[3] } = 1;
#
#	next if ( $line_count % $skip );
#
#	my $taxon_count = scalar( keys %subject_taxon_class );
#
#	if ( $end && $taxon_count > $end ) {
#		last;
#	}
#
#	if ( $taxon_count >= $start ) {
#		my $outfile_name
#			= $gi
#			. "_input_profile_"
#			. $line_count . "_"
#			. $taxon_count . ".prof";
#		my $full_outfile
#			= File::Spec->catfile( get_temp_dir_name(), $outfile_name );
#		open( my $outfile, ">$full_outfile" )
#			|| die "Can't open $full_outfile\n";
#
#		foreach my $t ( keys %subject_taxon_class ) {
#			print $outfile $t, "\t", 1, "\n";
#		}
#
#		foreach my $t ( keys %taxdis ) {
#			next if exists $subject_taxon_class{$t};
#			print $outfile $t, "\t", 0, "\n";
#		}
#
#		close($outfile) || die "Cant' write to $full_outfile\n";
#		my $result_output_file = File::Spec->catfile( get_temp_dir_name(),
#								   $gi . "_output_" . $line_count . ".result" );
#
#		my $prob = $taxon_count / $total_taxa_count;
#
#		system(
#			"perl $phylo_prof_bin -t $taxon --prob $prob -p $full_outfile -k @argv > $result_output_file"
#			) == 0
#			or die "Can't execute $phylo_prof_bin\n";
#		open( my $infile, $result_output_file )
#			|| die "Can't open $result_output_file\n";
#
#		my $last_score;
#
#		while ( my $line = <$infile> ) {
#			if ( $line =~ /^Locus/ ) {
#				next;
#			}
#			chomp $line;
#			my @f = split( /\t/, $line );
#			my ( $Locus, $Yes, $Total, $Depth, $Prob, $Score, $Desc ) = @f;
#
#			#				print STDERR "Score $Score\n";
#
#			#We want the hit to itself to be removed
#			if ( $Locus eq $gi ) {
#				next;
#			}
#
#			if ( $Score == 0.00 ) {
#				last;
#			} else {
#				$result_score{$line_count} = $Score;
#				$result_data{$line_count}  = \@f;
#				last;
#			}
#
#		}
#
#	}
#
#}
#
#print "#Subject_best_depth\tLocus\t\#Yes\t#Total\tDepth\tProb\tScore\tDesc\n";
#
#foreach my $key ( sort { $result_score{$a} <=> $result_score{$b} }
#				  keys %result_score )
#{
#
#	print $key, "\t", join( "\t", @{ $result_data{$key} } ), "\n";
#}

#	#	print STDERR "BLAST data\n";
#
#	#	foreach my $i ( keys %data ) {
#	#		print $i, "\t", $data{$i}, "\n";
#	#	}
#	close($blast_file);
#	my $blast =
#		PhyloProf::BlastResult->new( -data     => \%data,
#									 -value    => "e-value",
#									 -taxonomy => \%subject_taxon_class
#		);
#	return $blast->get_profile();
#
#	unless ($workspace) {
#
#		#$workspace = `pwd`;
#		croak "Workspace missing\n";
#	}
#
#	if ( $blast && ( !$genome_dir ) ) {
#		die "If you wanted to run blast then you must give a genome-dir\n";
#	}
#
#	my $username = $ENV{USER};
#
#	my $RUN_BLAST = 0;
#	unless ( if_exists_blast_results($taxon) ) {
#		croak
#			"Can't find blast result. Did you setup the database properly?\n";
#
#		#		$RUN_BLAST = 1;
#	}
#
#	if ($RUN_BLAST) {
#		print STDERR "Running blast...\n";
#		copy_blast_files($taxon);
#
#		run_blast();
#
#		#		split_blast($taxon);
#		parrellel_split_blast($taxon);
#	}
#
#	copy_ppp_files();
#
#	system("cp $profile $ppp_dir");
#	my ( $v, $dir, $file ) = File::Spec->splitpath($profile);
#	my $profile_file = File::Spec->catfile( $ppp_dir, $file );
#	my $inputdir = File::Spec->catdir( $ppp_dir, "input" );
#
#	if ( -d $inputdir ) {
#		system("rm -rf $inputdir") == 0 or croak "Can't remove $inputdir\n";
#		mkdir($inputdir) or die "$!";
#	}
#	else {
#		mkdir($inputdir) or die "$!";
#	}
#
#	#	unless ( -d $inputdir ) { mkdir($inputdir) or die "$!" }
#
#	write_input_files($inputdir);
#	opendir( DIR, $inputdir ) || die "Can't open $inputdir\n";
#
#	my $outputdir = File::Spec->catdir( $ppp_dir, "output" );
#	if ( -d $outputdir ) {
#		system("rm -rf $outputdir") == 0 or croak "Can't remove $outputdir\n";
#		mkdir($outputdir) or die "$!";
#	}
#	else {
#		mkdir($outputdir) or die "$!";
#	}
#	print STDERR "Scheduling jobs\n";
#
#	my $log_dir = File::Spec->catdir( $ppp_dir, "log" );
#	if ( -d $log_dir ) {
#		system("rm -rf $log_dir") == 0 or croak "Can't remove $log_dir\n";
#		mkdir($log_dir) or die "$!";
#	}
#	else {
#		mkdir($log_dir) or die "$!";
#	}
#
#	my $bin = __FILE__;
#	my $command
#		= "perl $bin --client -w $workspace -t $taxon --prob $probability -p $profile_file ";
#	if ($level) { $command .= "-l $level "; }
#
#	while ( my $file1 = readdir(DIR) ) {
#
#		#print STDERR $file, "\n";
#
#		next unless $file1 =~ /(\S+)\.sge$/;
#		my $inputfile  = File::Spec->catfile( $inputdir,  $file1 );
#		my $outputfile = File::Spec->catfile( $outputdir, $file1 );
#		my $logfile    = File::Spec->catfile( $log_dir,   $file1 . '.log' );
#
#		#print STDERR $outputfile, "\n";
#
#		if ( @jobs > $NP && $grid ) {    # Process limit has reached
#
#			gotosleep($NP);
#		}
#		elsif ( @jobs > $threads ) {
#			sleep_threads($NP);
#		}
#		else {
#
#			#			croak "Illegal operation\n";
#		}
#
#		my $full_command = $command . " -o $outputfile $inputfile";
#
#		if ( $serial || $threads == 1 ) {
#			launch_serial( $file1, $logfile, $full_command );
#		}
#		elsif ( $threads > 1 ) {
#			launch_threads( $file1, $logfile, $full_command );
#		}
#		elsif ($grid) {
#			croak
#				"This version of the program can not run on grid please wait for the next version\n";
#			launch_job(
#				$file1,
#				$logfile,
#
##			"$bin --client -w $workspace -t $taxon --prob $probability -p $profile_file -o $outputfile $inputfile"
#				$full_command
#			);
#		}
#		else {
#			croak "Run mode not given. Can be serial, threads or grid\n";
#		}
#	}
#
#	close(DIR);
#
#	if ( !$serial ) {
#		gotosleep(0);
#	}
#
#	my %locus_score;
#	my %yes;
#	my %number;
#	my %depth;
#	my %prob;
#
#	#	$locus_score{$locus} = $score;
#	#	$score{$score}       = 1;
#	#	$yes{$locus}         = $yes;
#	#	$number{$locus}      = $number;
#
#	opendir( my $output_dir_handle, $outputdir )
#		or die "Can't open $outputdir\n";
#
#	while ( my $output_file_name = readdir($output_dir_handle) ) {
#		my $full_path = File::Spec->catfile( $outputdir, $output_file_name );
#		open( my $output_file_handle, "$full_path" )
#			or die "Can't open $full_path\n";
#
#		while ( my $line = <$output_file_handle> ) {
#			chomp $line;
#			my @f = split( /\t/, $line );
#			$locus_score{ $f[0] } = $f[1];
#			$yes{ $f[0] }         = $f[2];
#			$number{ $f[0] }      = $f[3];
#			$depth{ $f[0] }       = $f[4];
#			$prob{ $f[0] }        = $f[5];
#		}
#		close($output_file_handle);
#	}
#	close($output_dir_handle);
#
#	my $desc_db = File::Spec->catfile( $db_dir, "desc", "gi_desc.sqlite3" );
#	my $dbh = DBI->connect( "dbi:SQLite:dbname=$desc_db", "", "",
#							{ RaiseError => 1, AutoCommit => 0 } );
#	my $sth = $dbh->prepare('select desc from gi_desc where gi =?');
#	print "Locus\t\#Yes\t#Total\tDepth\tProb\tScore\tDesc\n";
#
#	foreach my $s ( sort { $locus_score{$a} <=> $locus_score{$b} }
#					keys %locus_score )
#	{
#
#		#my $des = $cmr->get_des_by_id($s);
#		#unless ($des) { $des = ""; }
#		my $desc = "";
#		$sth->execute($s);
#		my @row = $sth->fetchrow_array();
#
#		if ( $row[0] ) {
#			$desc = $row[0];
#		}
#		print "$s\t", $yes{$s}, "\t", $number{$s}, "\t", $depth{$s}, "\t",
#			sprintf( "%.3f", $prob{$s} ), "\t",
#			sprintf( "%.3f", log( $locus_score{$s} ) / log(10) ),
#
#			"\t", $desc, "\n";
#	}
#	$sth->finish();
#	$dbh->disconnect();
#unless ($keep_files) {
#	rmtree($tmp_dir) || die "Can't remove $tmp_dir\n";
#}
#exit(0);
#
################### END SERVER MODE ###################################3
#
#if ($client) {
#
#	#print STDERR $output,"\t", $workspace, "\n";
#	$file = shift;
#	croak "Argument missing in client mode\n" unless $file;
#
#	open( my $input_file,  $file )      or die "Can't open $file\n";
#	open( my $output_file, ">$output" ) or die "Can't open $output\n";
#
#	my $taxonomy = SeqToolBox::Taxonomy->new();
#
#	#print STDERR "$taxonomy created\n";
#	my $ref_profile;
#
#	if ($level) {
#
#		#print STDERR "inside $level $taxonomy\n";
#		$ref_profile =
#			PhyloProf::Profile->new( -file     => $profile,
#									 -rank     => $level,
#									 -taxonomy => $taxonomy
#			);
#	} else {
#		$ref_profile =
#			PhyloProf::Profile->new( -file     => $profile,
#									 -taxonomy => $taxonomy );
#	}
#
#	while ( my $line = <$input_file> ) {
#		chomp $line;
#		my ( $volume, $path, $file_name ) = File::Spec->splitpath($line);
#		unless ($file_name) { die "Can't parse file name from $line\n"; }
#		my $locus;
#
#		if ( $file_name =~ /(\S+)\.bla/ ) {
#			$locus = $1;
#		}
#		unless ($locus) { die "Can't parse locus name from $file_name\n"; }
#		my $blast_profile = get_profile($line);
#
#		my @param = ( "-prof1" => $ref_profile, "-prof2" => $blast_profile );
#		if ( $probability > 0 ) {
#			push @param, "-prob", $probability;
#		}
#
#		if ($level) {
#			push @param, "-rank", $level;
#		}
#		print STDERR "Param: @param\n";
#		my $alg = PhyloProf::Algorithm::ppp->new(@param);
#		$alg->{_dbh} = $taxonomy;
#
##		if ($probability > 0) {
##		$alg
##			= PhyloProf::Algorithm::ppp->new( $ref_profile, $blast_profile, $probability );
##		}else {
##			$alg
##			= PhyloProf::Algorithm::ppp->new( $ref_profile, $blast_profile);
##		}
#		my ( $score, $yes, $number, $depth, $p ) = $alg->get_match_score();
#		print $output_file "$locus\t$score\t$yes\t$number\t$depth\t$p\n";
#	}
#
#	#	print "In client\n";
#	#	print STDERR $file, "\n";
#	#	open( FILE, ">$output" ) || die "Can't open $output\n";
#	#
#	#	print FILE "This is output of calling\n";
#	#	close(FILE);
#	close($input_file);
#	close($output_file);
#}
#
#sub get_profile {
#	my $file_name = shift;
#	open( my $blast_file, $file_name ) or die "Can't open $file_name\n";
#	my %data;
#	my %subject_taxon_class;
#
#	while ( my $line = <$blast_file> ) {
#		chomp $line;
#		my @f = split( /\t/, $line );
#		next if ( $f[0] eq $f[1] );
#
#		if ( exists $data{ $f[1] } ) {
#			if ( $data{ $f[1] } > $f[2] ) {
#				$data{ $f[1] } = $f[2];
#			}
#		} else {
#			$data{ $f[1] } = $f[2];
#		}
#
#		$subject_taxon_class{ $f[1] } = $f[3];
#	}
#	print STDERR "BLAST data\n";
#
#	#	foreach my $i ( keys %data ) {
#	#		print $i, "\t", $data{$i}, "\n";
#	#	}
#	close($blast_file);
#	my $blast =
#		PhyloProf::BlastResult->new( -data     => \%data,
#									 -value    => "e-value",
#									 -taxonomy => \%subject_taxon_class
#		);
#	return $blast->get_profile();
#
#}
#
#sub sleep_threads {
#	my $process_num = shift;
#
#	if ( $process_num == 0 ) {
#
#		#		foreach my $j (@jobs) {
#		#			waitpid($j, 0);
#		#		}
#		#		return;
#		while ( waitpid( -1, 0 ) != -1 ) {
#
#		}
#		return;
#	}
#
#	while (1) {
#
#		for ( my $i = 0; $i < @jobs; $i++ ) {
#			my $j = shift @jobs;
#
#			if ( waitpid( $j, WNOHANG ) > 0 ) {
#				next;
#			} else {
#				push @jobs, $j;
#			}
#		}
#
#		if ( @jobs < $threads ) {
#			last;
#		}
#	}
#
#}
#
#sub gotosleep {
#	my $process_num = shift;
#
#	if ( $process_num == 0 ) {
#		print STDERR "Waiting for the jobs to finish...\n";
#	} else {
#		print STDERR "Process limit has reached...waiting\n";
#	}
#
#	while (1) {
#
#		#		if ( $process_num == 0 ) {
#		#
#		#		} else {
#		#
#		#			print STDERR "Process limit has reached...waiting\n";
#		#		}
#		my %status;
#		my %machine;
#		my $jobstat = "qstat -u " . $ENV{USER} . ' |';
#
#		#		if ( $engine eq "LSF" ) {
#		#			$jobstat = "bjobs -a |";
#		#		}
#		open( PIPE, $jobstat );
#
#		while ( my $line = <PIPE> ) {
#			chomp $line;
#
#			if ( $line =~ /^JOBID/ || $line =~ /^job-ID/i || $line =~ /^-/ ) {
#				next;
#			}
#			my @fields = split( /\s+/, $line );
#
#			if ( $engine eq "LSF" ) {
#				$status{ $fields[0] } = $fields[2];
#
#				if ( $fields[5] =~ /(\S+)\.nc/ ) {
#					$machine{ $fields[0] } = $1;
#				}
#			} elsif ( $engine eq "SGE" ) {
#
#				if ( $SGE_version > 5 ) {
#					$status{ $fields[0] } = $fields[5];
#
#					if ( $fields[8] =~ /\@(\S+)/ ) {
#						$machine{ $fields[1] } = $1;
#					}
#				} else {
#					$status{ $fields[0] } = $fields[5];
#				}
#			} else {
#
#			}
#		}
#
#		close(PIPE);
#
#		for ( my $i = 0; $i < @jobs; $i++ ) {
#			my $pid = shift @jobs;
#
#			if (    !defined( $status{$pid} )
#				 || $status{$pid} eq "DONE"
#				 || $status{$pid} eq "EXIT" )
#			{
#				delete( $time{$pid} );
#				my $file = $pid_2_filename{$pid};
#				delete( $pid_2_filename{$pid} );
#
#				#delete_file ($file);
#
#			} else {
#				my $current_time = time();
#				my $start_time   = $time{$pid};
#
#				if ( $status{$pid} eq "PEND"
#					 && ( $current_time - $start_time ) > 1800 )
#				{
#					system("bkill $pid");
#
#					#$excluded_machines[@excluded_machines] = $machine{$pid};
#					delete( $time{$pid} );
#					my $file = $pid_2_filename{$pid};
#					print STDERR "Restarting job $file...\n";
#					delete( $pid_2_filename{$pid} );
#					$total_job--;
#					launch_job($file);
#
#				} elsif (    ( $status{$pid} eq "RUN" )
#						  && ( ( $current_time - $start_time ) > 1800 ) )
#				{
#					system("bkill $pid");
#
#					if ( exists $machine{$pid} ) {
#						$excluded_machines[@excluded_machines] = $machine{$pid};
#					}
#					delete( $time{$pid} );
#					my $file = $pid_2_filename{$pid};
#					print STDERR "Restarting job $file...\n";
#					$total_job--;
#					delete( $pid_2_filename{$pid} );
#					launch_job($file);
#
#				}
#
#				else {
#
#					push @jobs, $pid;
#				}
#			}
#
#		}
#
#		if ( @jobs <= $process_num ) {
#			my $num_jobs = scalar(@jobs);
#			print STDERR "Num of jobs: $num_jobs returning\n";
#			return 0;
#		} else {
#			my $num_jobs = scalar(@jobs);
#			print STDERR "Num of jobs: $num_jobs sleeping\n";
#			sleep 10;
#		}
#	}
#}
#
#sub launch_job {
#	my $filename = shift;
#	my $log      = shift;
#	my $command  = shift;
#
#	#my $basename = get_base_name($filename);
#	#my $logfile  = $LOG_DIR . '/' . $basename . '.log';
#	#my $outfile  = $OUTPUT_DIR . '/' . $basename . '.bla';
#	#my $infile   = $TEMP_DIR . '/' . $filename;
#	print STDERR "Scheduling jobs for $filename...";
#
#	my $lsf_options = $LSF_OPTIONS;
#
#	#	if (@excluded_machines) {
#	#		my $s = join( " ", @excluded_machines );
#	#		print STDERR "Excluding $s from the machine list...\n";
#	#		$lsf_options .= ' -m "' . $s . ' others+2"';
#	#
#	#	}
#	open( LSF, "$LSF $lsf_options -o $log -l fast $command|" );
#	$total_job++;
#
#	while ( my $line = <LSF> ) {
#
#		#		if ( $engine eq "LSF" ) {
#		#			if ( $line =~ /\<(\S+)\>/ ) {
#		#				$jobs[@jobs]        = $1;
#		#				$pid_2_filename{$1} = $filename;
#		#				$time{$1}           = time();
#		#
#		#			} else {
#		#				close LSF;
#		#				die "Can't schedule job\n";
#		#			}
#		#		}elsif ($engine eq "SGE") {
#		if ( $line =~ /Your\s+job\s+(\d+)\s+/ ) {
#			$jobs[@jobs]        = $1;
#			$pid_2_filename{$1} = $filename;
#			$time{$1}           = time();
#		} else {
#			close LSF;
#			die "Can't schedule job\n";
#		}
#
#		#		}else {
#		#
#		#		}
#	}
#	print STDERR "done\n";
#	close(LSF);
#
#}
#
#sub launch_serial {
#	my $filename = shift;
#	my $log      = shift;
#	my $command  = shift;
#	print STDERR "Running serial job $filename...";
#	system("$command 2> $log") == 0 or die "Can't schedule $filename\n";
#}
#
#sub launch_threads {
#	my $filename = shift;
#	my $log      = shift;
#	my $command  = shift;
#
#	#	my $lsf_options = $LSF_OPTIONS;
#
#	#	if (@excluded_machines) {
#	#		my $s = join( " ", @excluded_machines );
#	#		print STDERR "Excluding $s from the machine list...\n";
#	#		$lsf_options .= ' -m "' . $s . ' others+2"';
#	#
#	#	}
#	#	open( LSF, "$LSF $lsf_options -o $log -l fast $command|" );
#	$total_job++;
#	my $pid = fork();
#
#	if ($pid) {
#		$jobs[@jobs] = $pid;
#
#	} elsif ( $pid == 0 ) {
#		print STDERR "Running threads for $filename...";
#		system("$command 2> $log") == 0 or die "Can't schedule $filename\n";
#		exit;
#	} else {
#		die "Could not fork processes: $!" unless defined $pid;
#	}
#
#	#	while ( my $line = <LSF> ) {
#	#
#	#		#		if ( $engine eq "LSF" ) {
#	#		#			if ( $line =~ /\<(\S+)\>/ ) {
#	#		#				$jobs[@jobs]        = $1;
#	#		#				$pid_2_filename{$1} = $filename;
#	#		#				$time{$1}           = time();
#	#		#
#	#		#			} else {
#	#		#				close LSF;
#	#		#				die "Can't schedule job\n";
#	#		#			}
#	#		#		}elsif ($engine eq "SGE") {
#	#		if ( $line =~ /Your\s+job\s+(\d+)\s+/ ) {
#	#			$jobs[@jobs]        = $1;
#	#			$pid_2_filename{$1} = $filename;
#	#			$time{$1}           = time();
#	#		}
#	#		else {
#	#			close LSF;
#	#			die "Can't schedule job\n";
#	#		}
#	#
#	#		#		}else {
#	#		#
#	#		#		}
#	#	}
#	#	print STDERR "done\n";
#	#	close(LSF);
#}
#
#sub write_input_files {
#
#	#print STDERR "Creating input files...\n";
#	my $inputdir = shift;
#
#	#print STDERR "$inputdir\n";
#	my $split = 50;
#
#	#	my $taxon_blast_dir = File::Spec->catdir( $ppp_dir, "$taxon" );
#	my $taxon_blast_dir = File::Spec->catdir( $db_dir, "blast", $taxon );
#	opendir( DIR, $taxon_blast_dir ) || die "Can't open $taxon_blast_dir\n";
#
#	#print STDERR "After opening directory\n";
#	my $count    = 0;
#	my $lastfile = "";
#	my $last_gi  = 0;
#
#	while ( my $file = readdir(DIR) ) {
#
#		#print STDERR $file, "\n";
#		next unless $file =~ /(\S+)\.bla$/;
#		$count++;
#		$last_gi = $file;
#
#		#print STDERR $count, "\t", $file, "\n";
#		if ( $count != 1 && !( ( $count - 1 ) % $split ) ) {
#
#			#				print STDERR $line, "\n";
#			my $outfilename
#				= File::Spec->catfile( $inputdir, $last_gi . '.sge' );
#
#			#print STDERR $outfilename, "\n";
#			open( OUTFILE, ">$outfilename" )
#				|| die "Can't open $outfilename\n";
#			print OUTFILE $lastfile;
#			close(OUTFILE);
#
#		  #			$lastfile = File::Spec->catfile( $ppp_dir, $taxon, $file ) . "\n";
#			$lastfile = File::Spec->catfile( $taxon_blast_dir, $file ) . "\n";
#
#			#$lastgi  = "";
#		} else {
#
#			#						$lastfile .= "$file\n";
#			#			$lastfile
#			#				.= File::Spec->catfile( $ppp_dir, $taxon, $file ) . "\n";
#			$lastfile .= File::Spec->catfile( $taxon_blast_dir, $file ) . "\n";
#
#		}
#	}
#
#	my $outfilename = File::Spec->catfile( $inputdir, $last_gi . '.sge' );
#
#	#print STDERR $outfilename, "\n";
#	open( OUTFILE, ">$outfilename" )
#		|| die "Can't open $outfilename\n";
#	print OUTFILE $lastfile;
#	close(OUTFILE);
#
#	#			$lastfile = "$file\n";
#
#	close(DIR);
#}
#
#sub copy_ppp_files {
#
#	#	print STDERR "Copying PPP files\n";
#	my $t         = $taxon;
#	my $tmp_dir   = get_temp_dir_name();
#	my $blast_dir = File::Spec->catdir( $tmp_dir, "ppp" );
#
#	unless ( -s $blast_dir ) {
#		mkdir($blast_dir) or croak "Could not create $blast_dir\n";
#	}
#
#	#	my $blast_db_dir = File::Spec->catdir( $blast_dir, "$t" );
#	#
#	#	unless ( -d $blast_db_dir ) {
#	#		mkdir($blast_db_dir) or croak "Could not create $blast_db_dir\n";
#	#	}
#	#	$blast_db_dir .= '/';
#	#
#	#	my $source_blast_db_dir = File::Spec->catdir( $db_dir, "blast", $taxon );
#	#	$source_blast_db_dir .= '/';
#	#
#	#	#my $taxon_fasta_file    = File::Spec->catfile( $blast_dir, $t . '.fas' );
#	#	#my $taxon_source_file   = File::Spec->catfile( $db_dir, $t . '.fas' );
#	#
#	#	#	unless (-s $taxon_source_file) {
#	#	#		croak "Could not find $taxon_source_file\n";
#	#	#	}
#	#	#
#	#	#	unless ( -s $taxon_fasta_file ) {
#	#	#		system("cp $taxon_source_file $blast_dir") == 0
#	#	#			or croak "Could not copy $taxon_source_file to $blast_dir\n";
#	#	#	}
#	#	#print STDERR $source_blast_db_dir, "\t", $blast_db_dir, "\n";
#	#	system("rsync -a $source_blast_db_dir $blast_db_dir") == 0
#	#		or croak "Could not sync $source_blast_db_dir and $blast_db_dir\n";
#}
#
#sub run_blast {
#	my $bin_dir = $FindBin::Bin;
#
##	my $blast_bin = File::Spec->catfile($bin_dir,'..','util', 'cluster_blast.pl');
#	my $blast_bin = 'cluster_blast.pl';
#	print STDERR $blast_bin, "\n";
#	my $currdir   = cwd();
#	my $blast_dir = File::Spec->catdir( $tmp_dir, "blast" );
#	my $inputfile = $taxon . '.fas';
#	my $blastdb
#		= File::Spec->catfile( $blast_dir, 'blastdb', 'all.peptides.fa' );
#	my $testfile = $blastdb . '.pal';
#
#	unless ( -s $testfile ) {
#		croak "BLAST databases not found\n";
#	}
#	chdir($blast_dir) or croak "$!";
#
#	#	my $blast_options
#	#		= '-s 25 -b "-m 9 -e 0.01 -v 1500 -b 1500" -o '
#	#		. $taxon . '.bla' . ' -i '
#	#		. $inputfile . ' -d '
#	#		. $blastdb;
#	my $blast_options
#
#		= '-s 10 -b "-m 9 -e 0.01 -v 1500 -b 1500"' . ' -i '
#		. $inputfile . ' -d '
#		. $blastdb;
#
#	print STDERR $blast_options, "\n";
#
#	print "$blast_bin $blast_options\n";
#	system("$blast_bin $blast_options") == 0
#		or croak "Can't execute $blast_bin\n";
#	chdir($currdir) or croak "Could not change dir to $currdir\n";
#}
#
#sub split_blast {
#	print STDERR "Caching BLAST data\n";
#	my $taxon     = shift;
#	my $blast_dir = File::Spec->catdir( $tmp_dir, "blast" );
#	my $file      = File::Spec->catfile( $blast_dir, $taxon . '.bla' );
#	open( my $infile, $file ) || croak "Can't open $file\n";
#	my $out_dir = File::Spec->catdir( $db_dir, 'blast', "$taxon" );
#
#	unless ( -d $out_dir ) {
#		mkdir($out_dir) || die "$!";
#	}
#
#	my $taxonomy = SeqToolBox::Taxonomy->new();
#
#	while ( my $line = <$infile> ) {
#		next if $line =~ /^\#/;
#		chomp $line;
#		my @f = split( /\t/, $line );
#		my $q = $f[0];
#		my $s = $f[1];
#		my $e = $f[10];
#		my $q_gi;
#		my $s_gi;
#
#		if ( $e > 0.01 ) {
#			next;
#		}
#
#		if ( $q =~ /gi\|(\d+)/ ) {
#			$q_gi = $1;
#		}
#
#		unless ($q_gi) {
#			$q_gi = $q;
#		}
#
#		if ( $s =~ /gi\|(\d+)/ ) {
#			$s_gi = $1;
#		}
#
#		unless ($s_gi) {
#			$s_gi = $s;
#		}
#
#		my $taxon_class = $taxonomy->get_taxon($s_gi);
#		next unless $taxon_class;
#
#		my $outfile = File::Spec->catfile( $out_dir, $q_gi . '.bla' );
#		open( my $out, ">>$outfile" ) || die "Can't open $outfile\n";
#		print $out "$q_gi\t$s_gi\t$e\t$taxon_class\n";
#		close($out);
#	}
#	close($infile);
#}
#
#sub parrellel_split_blast {
#	print STDERR "Caching BLAST data over grid\n";
#	my $taxon = shift;
#	my $blast_dir = File::Spec->catdir( $tmp_dir, "blast", "output" );
#
#	unless ( -d $blast_dir ) {
#		croak "Could not file $blast_dir\n";
#	}
#
#	my $split_blast_dir = File::Spec->catdir( $tmp_dir, "ppp" );
#	my $split_blast_log_dir
#		= File::Spec->catdir( $tmp_dir, "blast", "split_output_log" );
#
#	unless ( -d $split_blast_dir ) {
#		system("mkdir $split_blast_dir") == 0
#			or die "Can't create $split_blast_dir\n";
#	}
#
#	unless ( -d $split_blast_log_dir ) {
#		system("mkdir $split_blast_log_dir") == 0
#			or die "Can't create $split_blast_log_dir\n";
#	}
#	opendir( my $bdir, $blast_dir ) || die "Can't open $blast_dir\n";
#
##	my $parse_command = "/usr/local/projects/TUNE/malay/Phyloprof/util/cache_blast_result.pl $taxon ";
#	my $parse_command
#		= "/usr/local/projects/TUNE/malay/Phyloprof/util/cache_blast_result.pl ";
#
#	while ( my $file = readdir($bdir) ) {
#		next unless $file =~ /\.bla$/;
#		my $fullname = File::Spec->catfile( $blast_dir,           $file );
#		my $log_name = File::Spec->catfile( $split_blast_log_dir, $file );
#		my $full_command = "$parse_command $fullname $split_blast_dir";
#
#		#print STDERR "Command: $full_command \n";
#		#$full_command .= $fullname;
#		#$full_command .= ' '.$split_blast_dir;
#		launch_job( $file, $log_name, $full_command );
#	}
#
#	close($bdir);
#	gotosleep(0);
#
#	#my $file      = File::Spec->catfile( $blast_dir, $taxon . '.bla' );
#	#open( my $infile, $file ) || croak "Can't open $file\n";
#	my $out_dir = File::Spec->catdir( $db_dir, 'blast', "$taxon" );
#
#	unless ( -d $out_dir ) {
#		mkdir($out_dir) || die "$!";
#	}
#
#	my $source_dir = File::Spec->catdir( $split_blast_dir, $taxon );
#	unless ( -d $source_dir ) {
#		die "$!";
#	}
#	$source_dir .= '/';
#
#	print STDERR "Syncing data to archive...\n";
#	system("rsync -a $source_dir $out_dir") == 0
#		or croak "Could not sync $source_dir and $out_dir\n";
#
#}
#
#sub copy_blast_files {
#	print STDERR "Copying BLAST files\n";
#	my $t         = shift;
#	my $tmp_dir   = get_temp_dir_name();
#	my $blast_dir = File::Spec->catdir( $tmp_dir, "blast" );
#
#	unless ( -d $blast_dir ) {
#		mkdir($blast_dir) or croak "Could not create $blast_dir\n";
#	}
#	my $blast_db_dir = File::Spec->catdir( $blast_dir, "blastdb" );
#
#	unless ( -d $blast_db_dir ) {
#		mkdir($blast_db_dir) or croak "Could not create $blast_db_dir\n";
#	}
#	$blast_db_dir .= '/';
#
#	my $source_blast_db_dir = File::Spec->catdir( $db_dir, "blastdb" );
#	$source_blast_db_dir .= '/';
#	my $taxon_fasta_file  = File::Spec->catfile( $blast_dir, $t . '.fas' );
#	my $taxon_source_file = File::Spec->catfile( $db_dir,    $t . '.fas' );
#
#	unless ( -s $taxon_source_file ) {
#		croak "Could not find $taxon_source_file\n";
#	}
#
#	unless ( -s $taxon_fasta_file ) {
#		system("cp $taxon_source_file $blast_dir") == 0
#			or croak "Could not copy $taxon_source_file to $blast_dir\n";
#	}
#
#	#print STDERR $source_blast_db_dir, "\t", $blast_db_dir, "\n";
#	system("rsync -a $source_blast_db_dir $blast_db_dir") == 0
#		or croak "Could not sync $source_blast_db_dir and $blast_db_dir\n";
#}
#
#sub if_exists_blast_results {
#
#	my $taxon = shift;
#
#	#print STDERR "$taxon\n";
#	my $dir = File::Spec->catdir( $db_dir, "blast", $taxon );
#
#	#print STDERR $dir, "\n";
#	if ( -d $dir ) {
#		return 1;
#	} else {
#		return;
#	}
#}
#
sub get_temp_dir_name {

	#	my @f = localtime();
	#my $year = 1900+$f[5];
	#	my $time_stamp = 1900+$f[5].1+$f[4].$f[3].$f[2].$f[1].$f[0];
	my $tmp_dir_name = File::Spec->catdir( $workspace, "tmp~" );

	unless ( -d $tmp_dir_name ) {
		system("mkdir $tmp_dir_name") == 0
		  or croak "Can't create $tmp_dir_name\n";

	}
	return $tmp_dir_name;
}

#
#sub read_tax_dis_file {
#	my $tax_dis_file
#		= File::Spec->catfile( $FindBin::Bin, "..", "data", "taxdis.txt" );
#	open( my $tax_dis, $tax_dis_file ) || die "Can't open $tax_dis_file\n";
#
#	while ( my $line = <$tax_dis> ) {
#		chomp $line;
#		$taxdis{$line} = 1;
#	}
#}
#
##DESTROY {
##	system ("qdel -u $username") == 0 or print STDERR "Can't remove all the jobs from the que\n";
##}
#
#exit(0);

