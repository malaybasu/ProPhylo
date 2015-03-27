#!/usr/bin/perl -w

# This script gets the genomes and stores it in local files from NCBI web site.

use Net::FTP;
use File::Listing qw(parse_dir);
use strict;
use Cwd;

my @dirs = ( "Bacteria_DRAFT", "Bacteria" );

#my @dirs = ( "Bacteria" );
my $ftp = Net::FTP->new( "ftp.ncbi.nih.gov", Debug => 0 )
	or die "Can't connet to host: $@";
$ftp->login( "anonymous", "anon@" )
	or die "Can't login", $ftp->message();
$ftp->binary();

foreach my $dir (@dirs) {
	unless ( stat $dir ) {
		system("mkdir $dir") == 0 || die "Can't create $dir\n";
	}
	my $current_dir = cwd();
	chdir $dir || die "Can't chage dir to $dir\n";
	$ftp->cwd("/genomes/$dir");

	my @dir = $ftp->dir();
	open( DIRLIST, ">dirlist.tmp" ) || die "Can't open dirlist to write\n";
	print DIRLIST join( "\n", @dir );
	close DIRLIST;
	open( DIRLIST, "dirlist.tmp" ) || die "Can't open dirlist to read\n";

	for ( parse_dir( \*DIRLIST ) ) {
		my ( $name, $type, @someother ) = @$_;

		if ( $type eq "d" ) {

			print "Changing dir to $name\n";

			if ( -s $name ) {

	# Directory already present locally but we need to check whether it is empty
				opendir( DIR, $name ) || die "Could not open $name\n";
				my $found = 0;

				while ( my $file = readdir(DIR) ) {
					if ( $file =~ /\fas/ || $file =~ /faa/ ) {
						$found = 1;
						last;
					}
				}
				close(DIR);

				if ($found) {
					print STDERR "$name alread exists, skipping\n";
					next;
				}else {
					print STDERR "Could not find any sequence file in $name! Removing\n";
					system ("rm -rf $name") == 0 || die "Could not remove $name\n";		
				}
			}
			$ftp->cwd($name);
			system("mkdir $name") unless stat($name);
			my @subdir = $ftp->dir();
			open( SUBDIRLIST, ">subdirlist.tmp" )
				|| die "Can't open subdirlist to write\n";
			print SUBDIRLIST join( "\n", @subdir );
			close(SUBDIRLIST);
			open( SUBDIRLIST, "subdirlist.tmp" )
				|| die "Can't open subdirlist to read\n";

			for ( parse_dir( \*SUBDIRLIST ) ) {
				my ( $subname, $type, @someother ) = @$_;
				next unless ( $subname && $type );
				my $localfile = $name . "/" . $subname;

				if ( $subname =~ /\.faa/ ) {
					my $true;
					eval { $true = $ftp->get( $subname, $localfile ); };

					if ($@) {
						print STDERR "Could not retrieve file $subname\n";
						next;
					} else {

						if ( $subname =~ /\.tgz$/ ) {
							print STDERR "Unzipping $subname\n";
							my $current_dir = cwd();
							chdir($name) || die "Can't chdir to $name\n";
							system("tar -xvzf $subname") == 0
								|| die "Can't unzip $subname\n";
							chdir($current_dir);
						} elsif ( $subname =~ /\.gz$/ ) {
							print STDERR "Unzipping $subname\n";
							my $current_dir = cwd();
							chdir($name) || die "Can't chdir to $name\n";
							system("gunzip $subname") == 0
								|| die "Can't unzip $subname\n";
							chdir($current_dir);
						} else {

						}
					}

				}

			}
			close(SUBDIRLIST);

			#print $ftp ->ls();
			$ftp->cwd("..");
		}

	}
	close DIRLIST;
	unlink "dirlist.tmp";
	unlink "subdirlist.tmp";
	chdir $current_dir || die "Can't chage dir to $current_dir\n";
}
