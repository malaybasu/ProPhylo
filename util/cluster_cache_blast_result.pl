#!/usr/local/bin/perl
# $Id: cluster_cache_blast_result.pl 500 2009-08-20 21:50:56Z malay $

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

ppp_grid.pl - This is a parallel implementation of Dan Haft's Partial Phylogenetic Profile algorithm, designed to run on on a compute cluster.

=head1 SYNOPSIS

ppp_grid.pl [options] -w workspace -d db_dir -t taxon -p profile > result


=head1 DESCRIPTION

The software runs PPP searches on any artibitrary sets of FASTA files. It runs BLAST in lazy mode: as and when required. It requires data is a specific mode to be present is a specific directory, called "database directory". The directory structure is like this:

 /-------ncbi_taxon_id.fas
  	|---blast
	|---blastdb
           |---<all.peptides.fa>

Where, "ncbi_taxon_id.fas" is a fasta file contatining the all the peptides from a particular genome. The filename should be like this: 12345.fas. You should have a fasta file contating every protein sequence that you would like to search, and name the file as "all.peptides.fa". Run formatdb on this file, and dump all the resulting files into a directory called "blastdb" under this directory. This file should have properly formatted NCBI GIs.

The software runs on on Sun Grid Engine (SGE). It also requires a set of modules classed SeqToolBox. Email Malay (mbasu@jcvi.org) for these modules.

Installation:

	1. Create a directory structure as described above. And put the data files in that directory. Pass the path of this directory name with -d options as shown below. This directory need not be grid accesible.
	2. Put these module sets (Phyloprof) in a directory of your choice. This directory should be accessible from all nodes of your cluster. Put the bin and the util directory of Phyloprof in your path.
	3. Put SeqToolBox is a cluster accessible directory. Put the install directory is your path.
	4. Make a cluster accesible directory (should hold about 2G of data). Put this directory name in an envrionment variable SEQTOOLBOX.
	5. Change directory to SEQTOOLBOX and run update_taxonomy.pl. This should download the taxonomy databases for NCBI website and set it up for you.
	6. Create a cluster accesible directory for writing temporay files. Pass this directory name to the program with -w option.

You are now ready to run PPP.

=head1 MANDETORY OPTIONS


=over 4

=item B<-w |--workspace path>

The name of the cluster accessible dirctory that will act as temporary space.

=item B<-d | --db path>

The data directory created as mentioned above.

=item B<-p | --profile>

A profile file with format as shown below:

 tax_id 1
 tax_id 0
...

This profile file will be searched against the database.

=item B<-t | --taxon ncbi_taxon_id>

NCBI taxon id for the genome that will be searched for the profile. The fasta file for this genome should be present is the data directory as mentioned above.

=back

=head1 OTHER OPTIONS

=over 4

=item B<-l | --level taxonomic_level>

The taxonomic level that should be searched; family, genus, species, etc. Any taxonomic rank as understood by NCBI taxonomy database can be used. The default is to do the search as taxon id level.

=item B<--prob probability>

This is the probabliity for the PPP algorithm. The default is to calculate the probablity from the the given profile.

=item B<-h | --help>
Print this help page.

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

# my $db_dir    = '/usr/local/archive/projects/PPP/split_genomes';
my $db_dir = '';
# my $client    = 0;
my $workspace = '';
my $taxon;
# my $profile;
# my $level   = '';
my $SGE     = "qsub -b y -j y -V";
# my $project = "0380";
# my $nodes   = 10;
my $help;
# my $copy;
my $file;
# my $program_name = File::Spec->catfile( $FindBin::Bin, 'ppp_grid.pl' );
# my $blast        = "";
# my $genome_dir   = "";
my $blastdb      = "";
my $output       = "";
my $NP           = 1000;
my $LSF          = "qsub";
# my $LSF_OPTIONS  = "-b y -j y -V -P 0380";
my $LSF_OPTIONS  = "-b y -j y -V ";
my $engine       = "SGE";
my $SGE_version  = 5;
my $probability  = 0;
# my $serial       = 0;

#print STDERR $program_name;

#
# Get the supplied command line options, and set flags
#

GetOptions(
	'help|h'        => \$help,
	'dir|d=s'       => \$db_dir,
	'workspace|w=s' => \$workspace,

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

######################## SERVER MODE ##################3

my $tmp_dir   = get_temp_dir_name();
# my $ppp_dir   = File::Spec->catdir( $tmp_dir, 'ppp' );
my $total_job = 0;
my @jobs;
my %pid_2_filename;
my %time;
my @excluded_machines;

parrellel_split_blast();

sub gotosleep {
	my $process_num = shift;

	if ( $process_num == 0 ) {
		print STDERR "Waiting for the jobs to finish...\n";
	}
	else {
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
			}
			elsif ( $engine eq "SGE" ) {

				if ( $SGE_version > 5 ) {
					$status{ $fields[0] } = $fields[5];

					if ( $fields[8] =~ /\@(\S+)/ ) {
						$machine{ $fields[1] } = $1;
					}
				}
				else {
					$status{ $fields[0] } = $fields[5];
				}
			}
			else {

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

			}
			else {
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

				}
				elsif (    ( $status{$pid} eq "RUN" )
						&& ( ( $current_time - $start_time ) > 1800 ) )
				{
					system("bkill $pid");

					if ( exists $machine{$pid} ) {
						$excluded_machines[@excluded_machines]
							= $machine{$pid};
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
		}
		else {
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
	# open( LSF, "$LSF $lsf_options -o $log -l fast $command|" );
	open( LSF, "$LSF $lsf_options -o $log $command|" );

	print STDERR "\n$LSF $lsf_options -o $log $command|\n";

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
		}
		else {
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

#sub launch_serial {
#	my $filename = shift;
#	my $log      = shift;
#	my $command  = shift;
#	print STDERR "Running serial job $filename...";
#	system ("$command 2> $log") == 0 or die "Can't schedule $filename\n";
#}
#sub write_input_files {
#
#	#print STDERR "Creating input files...\n";
#	my $inputdir = shift;
#
#	#print STDERR "$inputdir\n";
#	my $split = 50;
#	my $taxon_blast_dir = File::Spec->catdir( $ppp_dir, "$taxon" );
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
#			$lastfile = File::Spec->catfile( $ppp_dir, $taxon, $file ) . "\n";
#
#			#$lastgi  = "";
#		}
#		else {
#
#			#			$lastfile .= "$file\n";
#			$lastfile
#				.= File::Spec->catfile( $ppp_dir, $taxon, $file ) . "\n";
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

#sub copy_ppp_files {
#	print STDERR "Copying PPP files\n";
#	my $t         = $taxon;
#	my $tmp_dir   = get_temp_dir_name();
#	my $blast_dir = File::Spec->catdir( $tmp_dir, "ppp" );
#
#	unless ( -d $blast_dir ) {
#		mkdir($blast_dir) or croak "Could not create $blast_dir\n";
#	}
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
#}

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
##	my $blast_options
##		= '-s 25 -b "-m 9 -e 0.01 -v 1500 -b 1500" -o '
##		. $taxon . '.bla' . ' -i '
##		. $inputfile . ' -d '
##		. $blastdb;
#	my $blast_options
#
#		= '-s 25 -b "-m 9 -e 0.01 -v 1500 -b 1500"' . ' -i '
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
#		if ($e > 0.01) {
#			next;
#		}
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

sub parrellel_split_blast {
	print STDERR "Caching BLAST data over grid\n";

	#	my $taxon     = shift;
	my $blast_dir = File::Spec->catdir( $tmp_dir, "blast_output" );

	unless ( -d $blast_dir ) {
		croak "Could not file $blast_dir\n";
	}

	my $split_blast_dir = File::Spec->catdir( $tmp_dir, "split_blast" );
	my $split_blast_log_dir
		= File::Spec->catdir( $tmp_dir, "split_blast_log" );

	if ( -d $split_blast_dir ) {
		system ("rm -rf $split_blast_dir") == 0
			or die "Can't remove $split_blast_dir\n";

	}

	unless ( -d $split_blast_dir ) {
		system("mkdir $split_blast_dir") == 0
			or die "Can't create $split_blast_dir\n";
	}

	unless ( -d $split_blast_log_dir ) {
		system("mkdir $split_blast_log_dir") == 0
			or die "Can't create $split_blast_log_dir\n";
	}
	opendir( my $bdir, $blast_dir ) || die "Can't open $blast_dir\n";
	# my $parse_command = "perl /home/mbasu/projects/PhyloProf/util/cache_blast_result.pl ";
	# my $parse_command = "perl $FindBin::Bin/../util/cache_blast_result.pl ";
	my $parse_command = "perl $FindBin::Bin/cache_blast_result.pl ";

	while ( my $file = readdir($bdir) ) {
		# next unless $file =~ /\.bla$/;
		my $fullname = File::Spec->catfile( $blast_dir,           $file );
		my $log_name = File::Spec->catfile( $split_blast_log_dir, $file.".log");
		my $full_command = "$parse_command $fullname $split_blast_dir";
		print STDERR "$full_command\n";

		#print STDERR "Command: $full_command \n";
		#$full_command .= $fullname;
		#$full_command .= ' '.$split_blast_dir;
		if ( @jobs > $NP ) {    # Process limit has reached

		gotosleep($NP);
	}
		launch_job( $file, $log_name, $full_command );
	}

	close($bdir);
	gotosleep(0);

	opendir( my $s_b, $split_blast_dir )
		|| die "Can't open $split_blast_dir\n";

	while ( my $taxon = readdir($s_b) ) {
		if (!($taxon=~/\./)){

		my $source_dir = File::Spec->catdir( $split_blast_dir, $taxon );
		unless ( -d $source_dir ) {
			next;
		}
		$source_dir .= '/';

		# my $out_dir = File::Spec->catdir( $db_dir, 'blast', "$taxon" );
		my $out_dir = File::Spec->catdir( $db_dir, "$taxon" );
		print STDERR "outdir: $out_dir\n";
		unless ( -d $out_dir ) {
			mkdir($out_dir) || die "$!";
		}


		print STDERR "Syncing data to archive...\n";

		print STDERR "rsync -a $source_dir $out_dir\n";
		system("rsync -a $source_dir $out_dir") == 0
			or croak
			"Could not sync $source_dir and $out_dir\n";

	}
}
	close ($s_b);
	#my $file      = File::Spec->catfile( $blast_dir, $taxon . '.bla' );
	#open( my $infile, $file ) || croak "Can't open $file\n";

}

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
#	}
#	else {
#		return;
#	}
#}

sub get_temp_dir_name {

	#	my @f = localtime();
	#my $year = 1900+$f[5];
	#	my $time_stamp = 1900+$f[5].1+$f[4].$f[3].$f[2].$f[1].$f[0];
	my $tmp_dir_name = File::Spec->catdir( $workspace, "tmp" );

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
