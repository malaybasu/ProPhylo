#!/usr/bin/perl -w

# lsfcdsearch.pl - a program to submit cdsearch job to LSF queue.

# Usage: lsfcdsearch.pl <number of processes>

#  This program takes each file in the current directory and submits a
#  blast job to LSF queue. It submits only the specified number of jobs
#  to the queue and waits, till it finds free slot to sumbit more. The
#  program creates an output directory containing the result files and
#  a log directory containing the LSF output logs.

use Cwd;
use Getopt::Std;
use strict;
use File::Spec;

our (%opt);

getopt( 'iobdespr', \%opt );

#print $opt{i}, ',', $opt{o}, "\n";

my $composite_input  = $opt{i} || undef;
my $composite_output = $opt{o} || undef;

#my $program = $opt{p} || 'blastp';
my $database     = $opt{d} || die "Database is required option\n";
my $blastoptions = $opt{b} || "";
my $engine       = $opt{e} || "SGE";
my $split        = $opt{s} || 1;
my $NP           = $opt{p} || 10000;
my $resume       = $opt{r} || undef;

#if ( $opt{e} eq "LSF" || $opt{e} eq "lsf" ) {
#	$engine = "LSF";
#}

#print $composite_input, ',', $composite_output, "\n";

# Blast options

my $BLAST = "rpsblast -e 0.001 -F T -d $database ";

#my $BLAST   = "blastall -p blastp -d $database ";
#my $DB      = "-d $database";
my $OPTIONS = "$blastoptions";

my $SGE_version = 6;

# LSF commands
my $LSF;
my $LSF_OPTIONS = "";

if ( $engine eq "SGE" ) {
	$LSF         = "qsub";
	$LSF_OPTIONS = "-b y -j y -V -P 0380 ";
}
elsif ( $engine eq "LSF" ) {
	$LSF         = 'bsub';
	$LSF_OPTIONS = '-q "unified" -R "linux"';
}
else {

}

my @excluded_machines;

#my $LSF_OPTIONS = '-q "unified" -R "linux" -m "lfarm118 lfarm025 lfarm059 others+2"';

# Number of jobs that the script will submit at a time

#my $NP = 10;

#if ($ARGV[0]) {
##    $NP = $ARGV[0];
#}

# Output directories
my $CURRENT_DIR = cwd();

#my $CURRENT_DIR = $ENV{PWD};
my $OUTPUT_DIR = $CURRENT_DIR . '/output';
my $LOG_DIR    = $CURRENT_DIR . '/log';
my $TEMP_DIR   = $CURRENT_DIR . '/tmp';

if ( !stat($OUTPUT_DIR) ) {
	system("mkdir $OUTPUT_DIR") == 0 or die "Can't create output dir!\n";

}
else {

	unless ($resume) {
		system("rm -rf $OUTPUT_DIR") == 0 or die "Can't remove $OUTPUT_DIR\n";
		system("mkdir $OUTPUT_DIR") == 0  or die "Can't create output dir!\n";
	}
}

if ( !stat($LOG_DIR) ) {
	system("mkdir $LOG_DIR") == 0 or die "Can't create log dir!\n";
}
else {

	unless ($resume) {
		system("rm -rf $LOG_DIR") == 0 or die "Cant't remove $LOG_DIR\n";
		system("mkdir $LOG_DIR") == 0  or die "Can't create $LOG_DIR\n";
	}
}

if ( !stat($TEMP_DIR) ) {
	system("mkdir $TEMP_DIR") == 0 or die "Can't create log dir!\n";
}
else {

	if (!$resume && $composite_input) {
		system("rm -rf $TEMP_DIR") == 0 or die "Can't remove $TEMP_DIR\n";
		system("mkdir $TEMP_DIR") == 0  or die "Can't create $TEMP_DIR\n";
	}
}

my $total_seq          = 0;
my $total_job          = 0;
my $total_result       = 0;
my $total_returned_job = 0;

if ( $composite_input && !$resume ) {
	print STDERR "Splitting input file...";
	open( INFILE, $opt{i} ) || die "Can't open $opt{i}\n";
	my $lastseq = "";
	my $lastgi  = "";

	#	my $outfilename;
	#	my $data;

	while ( my $line = <INFILE> ) {
		if ( $line =~ /^>/ ) {
			$total_seq++;

			#			print STDERR $total_seq%$opt{s},"\n";
			if ( $total_seq != 1 && !( ( $total_seq - 1 ) % $split ) ) {

				#				print STDERR $line, "\n";
				my $outfilename = $TEMP_DIR . '/' . $lastgi . '.lsf';
				open( OUTFILE, ">$outfilename" )
					|| die "Can't open $outfilename\n";
				print OUTFILE $lastseq;
				close(OUTFILE);
				$lastseq = "";
				$lastgi  = "";
			}

			if ($lastgi) {

			 #				$outfilename = $TEMP_DIR . '/' . $lastgi . '.lsf';
			 #				open( OUTFILE, ">$outfile" ) || die "Can't open $outfile\n";
			 #				print OUTFILE $lastseq;
			 #				close(OUTFILE);

				$lastseq .= $line;
				$line =~ /^>(\S+)/;
				$lastgi = $1;
				$lastgi =~ s/[^0-9A-Za-z]/\_/g;

			}
			else {
				$lastseq = $line;
				$line =~ /^>(\S+)/;
				$lastgi = $1;
				$lastgi =~ s/[^0-9A-Za-z]/\_/g;

			}
		}
		else {
			$lastseq .= $line;
		}
	}

	if ($lastgi) {
		my $outfile = $TEMP_DIR . '/' . $lastgi . '.lsf';
		open( OUTFILE, ">$outfile" ) || die "Can't open $outfile\n";
		print OUTFILE $lastseq;
		close(OUTFILE);

		#	$lastseq = $line;
		#		$line =~ /^>(\S+)/;
		#		$lastgi = $1;
		#		$lastgi =~ s/[^0-9A-Za-z]/\_/g;
	}
	close(INFILE);
	print "done.\n";
}

# open the current dir and read one file at a time
opendir( DIR, $TEMP_DIR ) or die "Can't open $TEMP_DIR\n";

my $filename;    # stores the filename in the loop
my @jobs;        # a global array contains running job pids;
my $ext = "";
my %time;
my %pid_2_filename;

# main loop
if ($composite_input) {
	$ext = '.lsf';
}
else {

	#	$ext = '.fas';
	$ext = '.lsf';
}

while ( defined( $filename = readdir(DIR) ) ) {
	next if ( -d $filename );    # skip if it is a directory

	print STDERR $filename, "\n";
	next
		if ( $filename !~ /$ext$/ )
		;                        # skip if the file extension is not ".fas"

	my $basename = get_base_name($filename);
	my $logfile  = $LOG_DIR . '/' . $basename . '.log';
	my $outfile  = $OUTPUT_DIR . '/' . $basename . '.bla';

	#my $outfilesize = 0;
	#	my $logfilesize = 0;
	my $runthis = 1;

	#	if (stat ($outfile)) {
	#		$outfilesize = -s $outfile;
	#	}

	if ( $resume && stat($logfile) && ( -s $logfile == 0 ) && stat ($outfile)) {
		$runthis = 0;
	}

	if ( $runthis == 0 ) {
		next;
	}

	if ( stat($logfile) ) {
		system("rm $logfile") == 0
			or print STDERR "Could not remove $logfile\n";
	}

	if ( stat($outfile) ) {
		system("rm $outfile") == 0
			or print STDERR "Could not remove $outfile\n";
	}

	if ( @jobs > $NP ) {    # Process limit has reached

		gotosleep($NP);
	}

	launch_job($filename);
}

close(DIR);
print STDERR "Sucessfully completed scheduling.\n";

gotosleep(0);

#sub get_next_file {

#my $f = undef;
#while ( my $temp = readdir(DIR) ) {
#     next if (-d $temp); # skip if it is a directory

#     $f = $temp;
#     last;
# }

#        close (DIR);
#return $f;
#}

if ($composite_input) {
	print STDERR "Removing temp files ...\n";

	#system ("rmfile.pl \"*.lsf\"");
	#system("rm *.lsf");
	#	system("rm -rf $TEMP_DIR");
	system("rm -rf $TEMP_DIR") == 0
		or print STDERR "Could not remove $TEMP_DIR\n";
	print STDERR "Total sequence: $total_seq\n";
}

if ($composite_output) {
	print STDERR "Collating output ...";
	opendir( DIR, $OUTPUT_DIR ) or die "Can't open $OUTPUT_DIR\n";
	open( OUTFILE, ">$opt{o}" ) || die "Can't open $opt{o}\n";

	while ( defined( $filename = readdir(DIR) ) ) {

		my $infile = $OUTPUT_DIR . '/' . $filename;
		next if ( -d $infile );

		#		print STDERR $infile, "\n";
		$total_returned_job++;
		open( INFILE, "$infile" ) || die "Can't open $infile\n";

		while ( my $line = <INFILE> ) {
			if ( $line =~ /^Query\=/ ) {
				$total_result++;
			}
			print OUTFILE $line;
		}
		close(INFILE);
	}
	close(OUTFILE);
	close(DIR);

	#	system("rm -rf $OUTPUT_DIR");

	print STDERR "done.\n";
	print STDERR "Total result: $total_result\n";
	system("rm -rf $OUTPUT_DIR") == 0
		or print STDERR "Could not remove $OUTPUT_DIR\n";
}

print STDERR "Total returned jobs: $total_returned_job\n";
print STDERR "Total jobs: $total_job\n";

# system ("rm -rf $OUTPUT_DIR") == 0 or print STDERR "Could not remove $OUTPUT_DIR\n";
# system ("rm -rf $LOG_DIR") == 0 or print STDERR "Could not remove $LOG_DIR\n";
# system ("rm -rf $TEMP_DIR") == 0 or print STDERR "Could not remove $TEMP_DIR\n";
#my $LOG_DIR     = $CURRENT_DIR . '/log';
#my $TEMP_DIR    = $CURRENT_DIR . '/tmp';

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

		if ( $engine eq "LSF" ) {
			$jobstat = "bjobs -a |";
		}
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

					if ( defined( $fields[8] ) && $fields[8] =~ /\@(\S+)/ ) {
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
			sleep 60;
		}
	}
}

sub get_base_name {
	my $filename = shift;
	$filename =~ /^(\S+)\.[.]*?/;
	return $1;

}

sub delete_file {
	my $filename = shift;
	my $file     = $CURRENT_DIR . '/' . $filename;
	unlink($file);
}

sub launch_job {
	my $filename = shift;
	my $basename = get_base_name($filename);
	my $logfile  = $LOG_DIR . '/' . $basename . '.log';
	my $outfile  = $OUTPUT_DIR . '/' . $basename . '.bla';
	my $infile   = $TEMP_DIR . '/' . $filename;
	print STDERR "Scheduling jobs for $filename...";

	my $lsf_options = $LSF_OPTIONS;

	if (@excluded_machines) {
		my $s = join( " ", @excluded_machines );
		print STDERR "Excluding $s from the machine list...\n";
		$lsf_options .= ' -m "' . $s . ' others+2"';

	}
	open( LSF,
		"$LSF $lsf_options -o $logfile $BLAST $OPTIONS -i $infile -o $outfile|"
	);
	$total_job++;

	while ( my $line = <LSF> ) {
		if ( $engine eq "LSF" ) {

			if ( $line =~ /\<(\S+)\>/ ) {
				$jobs[@jobs]        = $1;
				$pid_2_filename{$1} = $filename;
				$time{$1}           = time();

			}
			else {
				close LSF;
				die "Can't schedule job\n";
			}
		}
		elsif ( $engine eq "SGE" ) {

			if ( $line =~ /Your\s+job\s+(\d+)\s+/ ) {
				$jobs[@jobs]        = $1;
				$pid_2_filename{$1} = $filename;
				$time{$1}           = time();
			}
			else {
				close LSF;
				die "Can't schedule job\n";
			}
		}
		else {

		}
	}
	print STDERR "done\n";
	close(LSF);

}

exit(0);
