#!/usr/local/bin/perl
# $Id: ppp.pl 633 2011-06-09 17:20:05Z malay $

##---------------------------------------------------------------------------##
##  File: ppp_grid.pl
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

ppp.pl - This is a parallel implementation of Partial Phylogenetic Profile (PPP) algorithm, designed to run on on a compute cluster.

=head1 SYNOPSIS

ppp.pl [options] -w workspace -d db_dir -t taxon -p profile > result


=head1 DESCRIPTION

The software runs PPP search on a particular genome. The genome is specified by NCBI taxon ID. It requires BLAST data is a specific mode to be present is a specific directory, called "database directory". The directory structure is like this:

  /--|--blast
     |   |---taxon_ID1/
     |           |--GI_number_1.bla
     |           |--GI_number_2.bla
     |           |....
     | 
     |--desc
   
The specified directory should contain a subdirectory named "blast". Under this subdirectory data for individual genomes are stored under their taxon ID. Each of these taxon ID directory should contain the BLAST result is a tabular format for individual GI for that genome.

It also requires a set of modules called SeqToolBox. You can download this modules from the software distribution FTP site: ftp://ftp.jcvi.org/pub/data/ppp/. Or, email Malay (mbasu@jcvi.org) for this module.

Installation:

The software is written using Perl. You need to install the following
Perl modules to correctly use this software.

  1. Math::Cephes
  2. Term::ProgressBar
  3. DBD::SQLite
  4. Bio::Perl (though not strictly needed for partial phylogenetic profile)

You can download and install these modules using standard perl installation.


Once you have installed these modules, download SeqToolBox from this
location.  ftp://ftp.jcvi.org/pub/data/ppp/software/seqtoolbox. Unzip it in
any directory of your choice. Add the SeqToolBox/lib directory to your PERL5LIB paths.


To use properly SeqToolBox, you need to create another directory where
you will store the SeqToolBox databases. This directory should have
atleast 1GB of space. Once you have created your directory, add it to
an environment variable SEQTOOLBOXDB. If you are using bash, you can
add this line to your .bash_profile export
SEQTOOLBOXDB=/the_directory_I_have_created/. Now you should download
the file,
ftp://ftp.jcvi.org/pub/data/ppp/seqtoolboxdb/seqtoolboxdb.tar.bz2
to this directory and unzip it:

cd /the_directory_i_have_created
wget ftp://ftp.jcvi.org/pub/data/ppp/seqtoolboxdb/seqtoolboxdb.tar.bz2
tar -xvjf seqtoolboxdb.tar.bz2

Now you have to download the PPP databases and set it up. You should
create another directory of your choice. The space required varies
depending on how many genomes you'd like to search. Once you have
created your directory create two subdirectories under it, desc and blast. 
The directory structure will be like this:

  ppp_dir
	  desc
	  blast

cd ppp_dir/desc
wget ftp://ftp.jcvi.org/pub/data/ppp/pppdb/desc/gi_desc.sqlite3.bz2
tar -xvjf gi_desc.sqlite3.bz2

The last but one step of the PPP search is to find the genome you are
interested in. The database with the software comes with ~1400
complete or partial genomes. If you have the taxon id you can download the specific genomes by,

cd ppp_dir/blast
wget ftp://ftp.jcvi.org/pub/data/ppp/pppdb/blast/taxon_id.tar.bz2 (replace the taxon_id of your choice)
tar -xvjf taxon_id.tar.bz2

The last step of the installation process in to download the ppp
software itself. Create a directory of your choice. Download the
latest version of the software from
ftp://ftp.jcvi.org/pub/data/ppp/software/phyloprof/ in this
directory. Unzip it and put the lib directory in your PERL5LIB path.

Now you have completed the installation.



=head1 MANDETORY OPTIONS


=over 4

=item B<-d | --db path>

The data directory created as mentioned above.

=item B<-p | --profile>

A profile file with format as shown below:

 tax_id 1
 tax_id 0
...

This profile file will be searched against the database.

=item B<-t | --taxon ncbi_taxon_id>

NCBI taxon id for the genome that will be searched for the profile. The BLAST result files should be present in the directory shown above.


=back

=head1 OTHER OPTIONS

=over 4

=item B<-h | --help>

Print this help page.

=item B<--serial>

Runs the software without any thread in serial mode. Can take a long time. Use it for only debugging purpose.


=item B<--threads interger>

You can run the software in parellel mode, if you have multicore processor. If you have a quad-core machine put 4 as the parameter. Default 1.


=item B<-l | --level taxonomic_level>

The taxonomic level that should be searched; family, genus, species, etc. Any taxonomic rank as understood by NCBI taxonomy database can be used. The default is to do the search as taxon id level. 

=item B<--prob probability>

This is the probabliity for the PPP algorithm. The default is to calculate the probablity from the the given profile.
	

=item B<--slope| -m fraction>

If given this is percentage difference that will be used to find a cutoff in the output. The output will be marked when the difference between the present score and the previous score is highter than this parameter. If not given the score for all the proteins in the genome is given in descending order without any marking. 

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
use File::Temp;
use File::Path;

#use PhyloProf::DB::CMR;
use PhyloProf::BlastResult;
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
my $file;
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
my $duplicate;
#print STDERR $program_name;

#
# Get the supplied command line options, and set flags
#

GetOptions(
	'help|h'          => \$help,
	'db|d=s'          => \$db_dir,
	'workspace|w=s'   => \$workspace,
	'taxon|t=i'       => \$taxon,
	'profile|p=s'     => \$profile,
	'level|l=s'       => \$level,
	'project|r=i'     => \$project,
	'nodes|n=i'       => \$nodes,
	'client'          => \$client,
	'copy|c'          => \$copy,
	'output|o=s'      => \$output,
	'prob=s'          => \$probability,
	'serial'          => \$serial,
	'threads=i'       => \$threads,
	'gi|g=i'          => \$dummy_gi,
	'start-depth|s=i' => \$dummy_start,
	'end-depth|e=i'   => \$dummy_end,
	'skip|j=i'        => \$dummy_skip,
	'slope|m=s'       => \$slope,
	'keep|k'		=> \$keep_files,
	'dup'			=>\$duplicate,	
		#			'blast|b'		=> \$blast,
		#			'genome|g=s'	=> \$genome_dir,
		#			'blastdb'	=>\$blastdb,
) or pod2usage( -verbose => 1 );

pod2usage( -verbose => 2 ) if $help;

######################## SERVER MODE ##################3

my $tmp_dir   = get_temp_dir_name();
my $ppp_dir   = File::Spec->catdir( $tmp_dir, 'ppp' );
my $total_job = 0;
my @jobs;
my %pid_2_filename;
my %time;
my @excluded_machines;

unless ($client) {

	pod2usage( -verbose => 1 ) unless ($taxon);
	pod2usage( -verbose => 1 ) unless ($profile);
	unless ( -s $profile ) {
		die "File $profile not found\n";
	}

	unless ($workspace) {

		#$workspace = `pwd`;
		croak "Workspace missing\n";
	}

	if ( $blast && ( !$genome_dir ) ) {
		die "If you wanted to run blast then you must give a genome-dir\n";
	}

	my $username = $ENV{USER};

	my $RUN_BLAST = 0;

	unless ( if_exists_blast_results($taxon) ) {
		croak "Can't find blast result. Did you setup the database properly?\n";

		#		$RUN_BLAST = 1;
	}

	if ($RUN_BLAST) {
		print STDERR "Running blast...\n";
		copy_blast_files($taxon);

		run_blast();

		#		split_blast($taxon);
		parrellel_split_blast($taxon);
	}

	copy_ppp_files();

	system("cp $profile $ppp_dir");
	my ( $v, $dir, $file ) = File::Spec->splitpath($profile);
	my $profile_file = File::Spec->catfile( $ppp_dir, $file );
	my $inputdir = File::Spec->catdir( $ppp_dir, "input" );

	if ( -d $inputdir ) {
		system("rm -rf $inputdir") == 0 or croak "Can't remove $inputdir\n";
		mkdir($inputdir) or die "$!";
	} else {
		mkdir($inputdir) or die "$!";
	}

	#	unless ( -d $inputdir ) { mkdir($inputdir) or die "$!" }

	write_input_files($inputdir);
	opendir( DIR, $inputdir ) || die "Can't open $inputdir\n";

	my $outputdir = File::Spec->catdir( $ppp_dir, "output" );
	if ( -d $outputdir ) {
		system("rm -rf $outputdir") == 0 or croak "Can't remove $outputdir\n";
		mkdir($outputdir) or die "$!";
	} else {
		mkdir($outputdir) or die "$!";
	}
	print STDERR "Scheduling jobs\n";

	my $log_dir = File::Spec->catdir( $ppp_dir, "log" );
	if ( -d $log_dir ) {
		system("rm -rf $log_dir") == 0 or croak "Can't remove $log_dir\n";
		mkdir($log_dir) or die "$!";
	} else {
		mkdir($log_dir) or die "$!";
	}

	my $bin = __FILE__;
	my $command
		= "perl $bin --client -w $workspace -t $taxon --prob $probability -p $profile_file ";
	if ($level) { $command .= "-l $level "; }
	if ($duplicate) {$command .= "--dup";}

	while ( my $file1 = readdir(DIR) ) {

		#print STDERR $file, "\n";

		next unless $file1 =~ /(\S+)\.sge$/;
		my $inputfile  = File::Spec->catfile( $inputdir,  $file1 );
		my $outputfile = File::Spec->catfile( $outputdir, $file1 );
		my $logfile    = File::Spec->catfile( $log_dir,   $file1 . '.log' );

		#print STDERR $outputfile, "\n";

		if ( @jobs > $NP && $grid ) {    # Process limit has reached
#print STDERR "Calling gotosleep\n";
			gotosleep($NP);
		} elsif ( @jobs > $threads ) {
#			print STDERR "Sleep theread called\n";
			sleep_threads($NP);
		} else {

			#			croak "Illegal operation\n";
		}

		my $full_command = $command . " -o $outputfile $inputfile";

		if ( $serial || $threads == 1 ) {
			launch_serial( $file1, $logfile, $full_command );
		} elsif ( $threads > 1 ) {
			launch_threads( $file1, $logfile, $full_command );
		} elsif ($grid) {
			croak
				"This version of the program can not run on grid please wait for the next version\n";
			launch_job(
				$file1,
				$logfile,

#			"$bin --client -w $workspace -t $taxon --prob $probability -p $profile_file -o $outputfile $inputfile"
				$full_command
			);
		} else {
			croak "Run mode not given. Can be serial, threads or grid\n";
		}
	}

	close(DIR);

	if ( !$serial && $grid ) {
#		print STDERR "Last iteration\n";
		gotosleep(0);
	}elsif (!$serial) {
		sleep_threads(0);
	}

	my %locus_score;
	my %yes;
	my %number;
	my %depth;
	my %prob;

	#	$locus_score{$locus} = $score;
	#	$score{$score}       = 1;
	#	$yes{$locus}         = $yes;
	#	$number{$locus}      = $number;

	opendir( my $output_dir_handle, $outputdir )
		or die "Can't open $outputdir\n";

	while ( my $output_file_name = readdir($output_dir_handle) ) {
		my $full_path = File::Spec->catfile( $outputdir, $output_file_name );
		open( my $output_file_handle, "$full_path" )
			or die "Can't open $full_path\n";

		while ( my $line = <$output_file_handle> ) {
			chomp $line;
			my @f = split( /\t/, $line );
			$locus_score{ $f[0] } = $f[1];
			$yes{ $f[0] }         = $f[2];
			$number{ $f[0] }      = $f[3];
			$depth{ $f[0] }       = $f[4];
			$prob{ $f[0] }        = $f[5];
		}
		close($output_file_handle);
	}
	close($output_dir_handle);

	my $desc_db = File::Spec->catfile( $db_dir, "desc", "gi_desc.sqlite3" );
	my $dbh = DBI->connect( "dbi:SQLite:dbname=$desc_db", "", "",
							{ RaiseError => 1, AutoCommit => 0 } );
	my $sth = $dbh->prepare('select desc from gi_desc where gi =?');
	print "Locus\t\#Yes\t#Total\tDepth\tProb\tScore\tDesc\n";

	my $last_score;
	my $cutoff_found;

	foreach my $s ( sort { $locus_score{$a} <=> $locus_score{$b} }
					keys %locus_score )
	{
		my $log_score = sprintf( "%.3f", log( $locus_score{$s} ) / log(10) );
		$last_score = $log_score unless $last_score;

		if ( $slope && $last_score && ( !$cutoff_found ) ) {
			my $p_last_score = $last_score < 0 ? -($last_score) : $last_score;
			my $p_s          = $log_score < 0  ? -($log_score)  : $log_score;
			my $delta = ( ( $p_last_score - $p_s ) / $p_last_score ) * 100;

			if ( $delta > $slope ) {
				print "-------------------------------------------\n";
				$cutoff_found = 1;
			}

		}

		#my $des = $cmr->get_des_by_id($s);
		#unless ($des) { $des = ""; }
		my $desc = "";
		$sth->execute($s);
		my @row = $sth->fetchrow_array();

		if ( $row[0] ) {
			$desc = $row[0];
		}
		print "$s\t", $yes{$s}, "\t", $number{$s}, "\t", $depth{$s}, "\t",
			sprintf( "%.3f", $prob{$s} ), "\t",
			handle_negative_zero(
						 sprintf( "%.3f", log( $locus_score{$s} ) / log(10) ) ),

			"\t", $desc, "\n";
	}
	$sth->finish();
	$dbh->disconnect();
	
	unless ($keep_files) {
#		system ("rm -f $tmp_dir") == 0 || die "Can't remove temporary files\n";
	    rmtree($tmp_dir) || die "Can't remove $tmp_dir\n";
	}
	exit(0);
}

################## END SERVER MODE ###################################3

if ($client) {

	#print STDERR $output,"\t", $workspace, "\n";
	$file = shift;
	croak "Argument missing in client mode\n" unless $file;

	open( my $input_file,  $file )      or die "Can't open $file\n";
	open( my $output_file, ">$output" ) or die "Can't open $output\n";

	my $taxonomy = SeqToolBox::Taxonomy->new();

	#print STDERR "$taxonomy created\n";
	my $ref_profile;

	if ($level) {

		#print STDERR "inside $level $taxonomy\n";
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

	while ( my $line = <$input_file> ) {
		chomp $line;
		my ( $volume, $path, $file_name ) = File::Spec->splitpath($line);
		unless ($file_name) { die "Can't parse file name from $line\n"; }
		my $locus;

		if ( $file_name =~ /(\S+)\.bla/ ) {
			$locus = $1;
		}
		unless ($locus) { die "Can't parse locus name from $file_name\n"; }
		my $blast_profile = get_profile($line);

		my @param = ( "-prof1" => $ref_profile, "-prof2" => $blast_profile );
		if ( $probability > 0 ) {
			push @param, "-prob", $probability;
		}

		if ($level) {
			push @param, "-rank", $level;
		}
		if ($duplicate) {
			push @param, "-dup",1;
		}
		print STDERR "Param: @param\n";
		my $alg = PhyloProf::Algorithm::ppp->new(@param);
		$alg->{_dbh} = $taxonomy;

#		if ($probability > 0) {
#		$alg
#			= PhyloProf::Algorithm::ppp->new( $ref_profile, $blast_profile, $probability );
#		}else {
#			$alg
#			= PhyloProf::Algorithm::ppp->new( $ref_profile, $blast_profile);
#		}
		my ( $score, $yes, $number, $depth, $p ) = $alg->get_match_score();
		print $output_file "$locus\t$score\t$yes\t$number\t$depth\t$p\n";
	}

	#	print "In client\n";
	#	print STDERR $file, "\n";
	#	open( FILE, ">$output" ) || die "Can't open $output\n";
	#
	#	print FILE "This is output of calling\n";
	#	close(FILE);
	close($input_file);
	close($output_file);
}

sub handle_negative_zero {
	my $num_str = shift;

	if ( $num_str =~ /^-([0\.]+)$/ ) {
		return $1;
	}
	eles {
		return $num_str;
	}
}

sub get_profile {
	my $file_name = shift;
	open( my $blast_file, $file_name ) or die "Can't open $file_name\n";
	my %data;
	my @values;
	my %subject_taxon_class;

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

	while ( my $line = <$blast_file> ) {
		chomp $line;
		my @f = split( /\t/, $line );
		# As per request by Dan on May 4, 2011 the self hit should be reported.
#		next if ( $f[0] eq $f[1] );

		if ( exists $data{ $f[1] } ) {
			if ( $data{ $f[1] } > $f[2] ) {
				$data{ $f[1] } = $f[2];
			}
		} else {
			$data{ $f[1] } = $f[2];
			push @values, $f[1];
		}

		$subject_taxon_class{ $f[1] } = $f[3];
	}
	print STDERR "BLAST data\n";

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
		PhyloProf::BlastResult->new( -data     => \@values,
									 -value    => "e-value",
									 -sorted => 1,
									 -taxonomy => \%subject_taxon_class
		);
	return $blast->get_profile();

}

sub sleep_threads {
	my $process_num = shift;

	if ( $process_num == 0 ) {

		#		foreach my $j (@jobs) {
		#			waitpid($j, 0);
		#		}
		#		return;
		while ( waitpid( -1, 0 ) != -1 ) {

		}
		return;
	}

	while (1) {

		for ( my $i = 0; $i < @jobs; $i++ ) {
			my $j = shift @jobs;

			if ( waitpid( $j, WNOHANG ) > 0 ) {
				next;
			} else {
				push @jobs, $j;
			}
		}

		if ( @jobs < $threads ) {
			last;
		}
	}

}

sub gotosleep {
	my $process_num = shift;

	if ( $process_num == 0 ) {
		print STDERR "Waiting for the jobs to finish...\n";
	} else {
		print STDERR "Process limit has reached...waiting\n";
	}

	while (1) {

		#		if ( $process_num == 0 ) {
		#
		#		} else {
		#
		#			print STDERR "Process limit has reached...waiting\n";
		#		}
		my %status;
		my %machine;
		my $jobstat = "qstat -u " . $ENV{USER} . ' |';

		#		if ( $engine eq "LSF" ) {
		#			$jobstat = "bjobs -a |";
		#		}
		open( PIPE, $jobstat );

		while ( my $line = <PIPE> ) {
			chomp $line;

			if ( $line =~ /^JOBID/ || $line =~ /^job-ID/i || $line =~ /^-/ ) {
				next;
			}
			my @fields = split( /\s+/, $line );

			if ( $engine eq "LSF" ) {
				$status{ $fields[0] } = $fields[2];

				if ( $fields[5] =~ /(\S+)\.nc/ ) {
					$machine{ $fields[0] } = $1;
				}
			} elsif ( $engine eq "SGE" ) {

				if ( $SGE_version > 5 ) {
					$status{ $fields[0] } = $fields[5];

					if ( $fields[8] =~ /\@(\S+)/ ) {
						$machine{ $fields[1] } = $1;
					}
				} else {
					$status{ $fields[0] } = $fields[5];
				}
			} else {

			}
		}

		close(PIPE);

		for ( my $i = 0; $i < @jobs; $i++ ) {
			my $pid = shift @jobs;

			if (    !defined( $status{$pid} )
				 || $status{$pid} eq "DONE"
				 || $status{$pid} eq "EXIT" )
			{
				delete( $time{$pid} );
				my $file = $pid_2_filename{$pid};
				delete( $pid_2_filename{$pid} );

				#delete_file ($file);

			} else {
				my $current_time = time();
				my $start_time   = $time{$pid};

				if ( $status{$pid} eq "PEND"
					 && ( $current_time - $start_time ) > 1800 )
				{
					system("bkill $pid");

					#$excluded_machines[@excluded_machines] = $machine{$pid};
					delete( $time{$pid} );
					my $file = $pid_2_filename{$pid};
					print STDERR "Restarting job $file...\n";
					delete( $pid_2_filename{$pid} );
					$total_job--;
					launch_job($file);

				} elsif (    ( $status{$pid} eq "RUN" )
						  && ( ( $current_time - $start_time ) > 1800 ) )
				{
					system("bkill $pid");

					if ( exists $machine{$pid} ) {
						$excluded_machines[@excluded_machines] = $machine{$pid};
					}
					delete( $time{$pid} );
					my $file = $pid_2_filename{$pid};
					print STDERR "Restarting job $file...\n";
					$total_job--;
					delete( $pid_2_filename{$pid} );
					launch_job($file);

				}

				else {

					push @jobs, $pid;
				}
			}

		}

		if ( @jobs <= $process_num ) {
			my $num_jobs = scalar(@jobs);
			print STDERR "Num of jobs: $num_jobs returning\n";
			return 0;
		} else {
			my $num_jobs = scalar(@jobs);
			print STDERR "Num of jobs: $num_jobs sleeping\n";
			sleep 10;
		}
	}
}

sub launch_job {
	my $filename = shift;
	my $log      = shift;
	my $command  = shift;

	#my $basename = get_base_name($filename);
	#my $logfile  = $LOG_DIR . '/' . $basename . '.log';
	#my $outfile  = $OUTPUT_DIR . '/' . $basename . '.bla';
	#my $infile   = $TEMP_DIR . '/' . $filename;
	print STDERR "Scheduling jobs for $filename...";

	my $lsf_options = $LSF_OPTIONS;

	#	if (@excluded_machines) {
	#		my $s = join( " ", @excluded_machines );
	#		print STDERR "Excluding $s from the machine list...\n";
	#		$lsf_options .= ' -m "' . $s . ' others+2"';
	#
	#	}
	open( LSF, "$LSF $lsf_options -o $log -l fast $command|" );
	$total_job++;

	while ( my $line = <LSF> ) {

		#		if ( $engine eq "LSF" ) {
		#			if ( $line =~ /\<(\S+)\>/ ) {
		#				$jobs[@jobs]        = $1;
		#				$pid_2_filename{$1} = $filename;
		#				$time{$1}           = time();
		#
		#			} else {
		#				close LSF;
		#				die "Can't schedule job\n";
		#			}
		#		}elsif ($engine eq "SGE") {
		if ( $line =~ /Your\s+job\s+(\d+)\s+/ ) {
			$jobs[@jobs]        = $1;
			$pid_2_filename{$1} = $filename;
			$time{$1}           = time();
		} else {
			close LSF;
			die "Can't schedule job\n";
		}

		#		}else {
		#
		#		}
	}
	print STDERR "done\n";
	close(LSF);

}

sub launch_serial {
	my $filename = shift;
	my $log      = shift;
	my $command  = shift;
	print STDERR "Running serial job $filename...\n";
	system("$command 2> $log") == 0 or die "Can't schedule $filename\n";
}

sub launch_threads {
	my $filename = shift;
	my $log      = shift;
	my $command  = shift;

	#	my $lsf_options = $LSF_OPTIONS;

	#	if (@excluded_machines) {
	#		my $s = join( " ", @excluded_machines );
	#		print STDERR "Excluding $s from the machine list...\n";
	#		$lsf_options .= ' -m "' . $s . ' others+2"';
	#
	#	}
	#	open( LSF, "$LSF $lsf_options -o $log -l fast $command|" );
	$total_job++;
	my $pid = fork();

	if ($pid) {
		$jobs[@jobs] = $pid;

	} elsif ( $pid == 0 ) {
		print STDERR "Running threads for $filename...\n";
#		print STDERR $command, "\n";
		system("$command 2> $log") == 0 or die "Can't schedule $filename\n";
		exit;
	} else {
		die "Could not fork processes: $!" unless defined $pid;
	}

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
	#		}
	#		else {
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
}

sub write_input_files {

	#print STDERR "Creating input files...\n";
	my $inputdir = shift;

	#print STDERR "$inputdir\n";
	my $split = 50;

	#	my $taxon_blast_dir = File::Spec->catdir( $ppp_dir, "$taxon" );
	my $taxon_blast_dir = File::Spec->catdir( $db_dir, "blast", $taxon );
	opendir( DIR, $taxon_blast_dir ) || die "Can't open $taxon_blast_dir\n";

	#print STDERR "After opening directory\n";
	my $count    = 0;
	my $lastfile = "";
	my $last_gi  = 0;

	while ( my $file = readdir(DIR) ) {

		#print STDERR $file, "\n";
		next unless $file =~ /(\S+)\.bla$/;
		$count++;
		$last_gi = $file;

		#print STDERR $count, "\t", $file, "\n";
		if ( $count != 1 && !( ( $count - 1 ) % $split ) ) {

			#				print STDERR $line, "\n";
			my $outfilename
				= File::Spec->catfile( $inputdir, $last_gi . '.sge' );

			#print STDERR $outfilename, "\n";
			open( OUTFILE, ">$outfilename" )
				|| die "Can't open $outfilename\n";
			print OUTFILE $lastfile;
			close(OUTFILE);

		  #			$lastfile = File::Spec->catfile( $ppp_dir, $taxon, $file ) . "\n";
			$lastfile = File::Spec->catfile( $taxon_blast_dir, $file ) . "\n";

			#$lastgi  = "";
		} else {

			#						$lastfile .= "$file\n";
			#			$lastfile
			#				.= File::Spec->catfile( $ppp_dir, $taxon, $file ) . "\n";
			$lastfile .= File::Spec->catfile( $taxon_blast_dir, $file ) . "\n";

		}
	}

	my $outfilename = File::Spec->catfile( $inputdir, $last_gi . '.sge' );

	#print STDERR $outfilename, "\n";
	open( OUTFILE, ">$outfilename" )
		|| die "Can't open $outfilename\n";
	print OUTFILE $lastfile;
	close(OUTFILE);

	#			$lastfile = "$file\n";

	close(DIR);
}

sub copy_ppp_files {

	#	print STDERR "Copying PPP files\n";
	my $t = $taxon;

	#	my $tmp_dir   = get_temp_dir_name();
	my $blast_dir = File::Spec->catdir( $tmp_dir, "ppp" );

	unless ( -s $blast_dir ) {
		mkdir($blast_dir) or croak "Could not create $blast_dir\n";
	}

	#	my $blast_db_dir = File::Spec->catdir( $blast_dir, "$t" );
	#
	#	unless ( -d $blast_db_dir ) {
	#		mkdir($blast_db_dir) or croak "Could not create $blast_db_dir\n";
	#	}
	#	$blast_db_dir .= '/';
	#
	#	my $source_blast_db_dir = File::Spec->catdir( $db_dir, "blast", $taxon );
	#	$source_blast_db_dir .= '/';
	#
	#	#my $taxon_fasta_file    = File::Spec->catfile( $blast_dir, $t . '.fas' );
	#	#my $taxon_source_file   = File::Spec->catfile( $db_dir, $t . '.fas' );
	#
	#	#	unless (-s $taxon_source_file) {
	#	#		croak "Could not find $taxon_source_file\n";
	#	#	}
	#	#
	#	#	unless ( -s $taxon_fasta_file ) {
	#	#		system("cp $taxon_source_file $blast_dir") == 0
	#	#			or croak "Could not copy $taxon_source_file to $blast_dir\n";
	#	#	}
	#	#print STDERR $source_blast_db_dir, "\t", $blast_db_dir, "\n";
	#	system("rsync -a $source_blast_db_dir $blast_db_dir") == 0
	#		or croak "Could not sync $source_blast_db_dir and $blast_db_dir\n";
}

sub run_blast {
	my $bin_dir = $FindBin::Bin;

#	my $blast_bin = File::Spec->catfile($bin_dir,'..','util', 'cluster_blast.pl');
	my $blast_bin = 'cluster_blast.pl';
	print STDERR $blast_bin, "\n";
	my $currdir   = cwd();
	my $blast_dir = File::Spec->catdir( $tmp_dir, "blast" );
	my $inputfile = $taxon . '.fas';
	my $blastdb
		= File::Spec->catfile( $blast_dir, 'blastdb', 'all.peptides.fa' );
	my $testfile = $blastdb . '.pal';

	unless ( -s $testfile ) {
		croak "BLAST databases not found\n";
	}
	chdir($blast_dir) or croak "$!";

	#	my $blast_options
	#		= '-s 25 -b "-m 9 -e 0.01 -v 1500 -b 1500" -o '
	#		. $taxon . '.bla' . ' -i '
	#		. $inputfile . ' -d '
	#		. $blastdb;
	my $blast_options

		= '-s 10 -b "-m 9 -e 0.01 -v 1500 -b 1500"' . ' -i '
		. $inputfile . ' -d '
		. $blastdb;

	print STDERR $blast_options, "\n";

	print "$blast_bin $blast_options\n";
	system("$blast_bin $blast_options") == 0
		or croak "Can't execute $blast_bin\n";
	chdir($currdir) or croak "Could not change dir to $currdir\n";
}

sub split_blast {
	print STDERR "Caching BLAST data\n";
	my $taxon     = shift;
	my $blast_dir = File::Spec->catdir( $tmp_dir, "blast" );
	my $file      = File::Spec->catfile( $blast_dir, $taxon . '.bla' );
	open( my $infile, $file ) || croak "Can't open $file\n";
	my $out_dir = File::Spec->catdir( $db_dir, 'blast', "$taxon" );

	unless ( -d $out_dir ) {
		mkdir($out_dir) || die "$!";
	}

	my $taxonomy = SeqToolBox::Taxonomy->new();

	while ( my $line = <$infile> ) {
		next if $line =~ /^\#/;
		chomp $line;
		my @f = split( /\t/, $line );
		my $q = $f[0];
		my $s = $f[1];
		my $e = $f[10];
		my $q_gi;
		my $s_gi;

		if ( $e > 0.01 ) {
			next;
		}

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

		my $taxon_class = $taxonomy->get_taxon($s_gi);
		next unless $taxon_class;

		my $outfile = File::Spec->catfile( $out_dir, $q_gi . '.bla' );
		open( my $out, ">>$outfile" ) || die "Can't open $outfile\n";
		print $out "$q_gi\t$s_gi\t$e\t$taxon_class\n";
		close($out);
	}
	close($infile);
}

sub parrellel_split_blast {
	print STDERR "Caching BLAST data over grid\n";
	my $taxon = shift;
	my $blast_dir = File::Spec->catdir( $tmp_dir, "blast", "output" );

	unless ( -d $blast_dir ) {
		croak "Could not file $blast_dir\n";
	}

	my $split_blast_dir = File::Spec->catdir( $tmp_dir, "ppp" );
	my $split_blast_log_dir
		= File::Spec->catdir( $tmp_dir, "blast", "split_output_log" );

	unless ( -d $split_blast_dir ) {
		system("mkdir $split_blast_dir") == 0
			or die "Can't create $split_blast_dir\n";
	}

	unless ( -d $split_blast_log_dir ) {
		system("mkdir $split_blast_log_dir") == 0
			or die "Can't create $split_blast_log_dir\n";
	}
	opendir( my $bdir, $blast_dir ) || die "Can't open $blast_dir\n";

#	my $parse_command = "/usr/local/projects/TUNE/malay/Phyloprof/util/cache_blast_result.pl $taxon ";
	my $parse_command
		= "/usr/local/projects/TUNE/malay/Phyloprof/util/cache_blast_result.pl ";

	while ( my $file = readdir($bdir) ) {
		next unless $file =~ /\.bla$/;
		my $fullname = File::Spec->catfile( $blast_dir,           $file );
		my $log_name = File::Spec->catfile( $split_blast_log_dir, $file );
		my $full_command = "$parse_command $fullname $split_blast_dir";

		#print STDERR "Command: $full_command \n";
		#$full_command .= $fullname;
		#$full_command .= ' '.$split_blast_dir;
		launch_job( $file, $log_name, $full_command );
	}

	close($bdir);
	gotosleep(0);

	#my $file      = File::Spec->catfile( $blast_dir, $taxon . '.bla' );
	#open( my $infile, $file ) || croak "Can't open $file\n";
	my $out_dir = File::Spec->catdir( $db_dir, 'blast', "$taxon" );

	unless ( -d $out_dir ) {
		mkdir($out_dir) || die "$!";
	}

	my $source_dir = File::Spec->catdir( $split_blast_dir, $taxon );
	unless ( -d $source_dir ) {
		die "$!";
	}
	$source_dir .= '/';

	print STDERR "Syncing data to archive...\n";
	system("rsync -a $source_dir $out_dir") == 0
		or croak "Could not sync $source_dir and $out_dir\n";

}

sub copy_blast_files {
	print STDERR "Copying BLAST files\n";
	my $t = shift;

	#	my $tmp_dir   = get_temp_dir_name();
	my $blast_dir = File::Spec->catdir( $tmp_dir, "blast" );

	unless ( -d $blast_dir ) {
		mkdir($blast_dir) or croak "Could not create $blast_dir\n";
	}
	my $blast_db_dir = File::Spec->catdir( $blast_dir, "blastdb" );

	unless ( -d $blast_db_dir ) {
		mkdir($blast_db_dir) or croak "Could not create $blast_db_dir\n";
	}
	$blast_db_dir .= '/';

	my $source_blast_db_dir = File::Spec->catdir( $db_dir, "blastdb" );
	$source_blast_db_dir .= '/';
	my $taxon_fasta_file  = File::Spec->catfile( $blast_dir, $t . '.fas' );
	my $taxon_source_file = File::Spec->catfile( $db_dir,    $t . '.fas' );

	unless ( -s $taxon_source_file ) {
		croak "Could not find $taxon_source_file\n";
	}

	unless ( -s $taxon_fasta_file ) {
		system("cp $taxon_source_file $blast_dir") == 0
			or croak "Could not copy $taxon_source_file to $blast_dir\n";
	}

	#print STDERR $source_blast_db_dir, "\t", $blast_db_dir, "\n";
	system("rsync -a $source_blast_db_dir $blast_db_dir") == 0
		or croak "Could not sync $source_blast_db_dir and $blast_db_dir\n";
}

sub if_exists_blast_results {

	my $taxon = shift;

	#print STDERR "$taxon\n";
	my $dir = File::Spec->catdir( $db_dir, "blast", $taxon );

	#	print STDERR $dir, "\n";
	if ( -d $dir ) {
		return 1;
	} else {
		return;
	}
}

sub get_temp_dir_name {

	#	print STDERR "get_temp_dir_name called\n";
	#	if (defined $tmp_dir) {
	#		return $tmp_dir;
	#	}
	#	my @f = localtime();
	#my $year = 1900+$f[5];
	#	my $time_stamp = 1900+$f[5].1+$f[4].$f[3].$f[2].$f[1].$f[0];
	my $tmp_dir_name = File::Spec->catdir( $workspace, "tmp~" );

#	my $tmp_dir_name = File::Temp->newdir('tmpXXXXX',DIR=> $workspace, CLEANUP=>0);
	unless ( -d $tmp_dir_name ) {
		system("mkdir $tmp_dir_name") == 0
			or croak "Can't create $tmp_dir_name\n";

	}
	return $tmp_dir_name;
}

#DESTROY {
#	system ("qdel -u $username") == 0 or print STDERR "Can't remove all the jobs from the que\n";
#}

exit(0);

