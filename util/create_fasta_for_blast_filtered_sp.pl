#!/usr/bin/env perl
# $Id$

##---------------------------------------------------------------------------##
##  File: create_fasta_for_blast_filtered_sp.pl
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

create_fasta_for_blast_filtered_sp.pl - One line description.

=head1 SYNOPSIS

create_fasta_for_blast_filtered_sp.pl [options] -o <option>


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
use File::Spec;

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

_check_params( \%options );

my $file = shift;    # file for filtering
my $dir  = shift; # directory containing genomes
                  # (Should contain a Bacteria and Bacteria_DRAFT directory).

my $data;						
open( INFILE, $file ) || die "Can't open $file\n";

while ( my $line = <INFILE> ) {
    chomp $line;
    next if $. == 1;
    my @f = split( /\t/, $line );
    	my $keep = $f[4];	   # keep /delete
	next if ($keep eq "delete");
	my $status = $f[3];    # complete/draft
	my $sp = $f[0];
	my $subdirectory;
	
	if ($status eq "complete") {
	  $subdirectory = "Bacteria";
	}elsif ($status = "draft") {
	  $subdirectory = "Bacteria_DRAFT";
	}else {
	  die "Unknown status flag\n";
	}

    my $full_directory_name = File::Spec->catdir($dir, $subdirectory, $sp);
	unless (-d $full_directory_name) {
	  die "Could not find directory $full_directory_name\n";
	}
	print STDERR "$sp\n";

	opendir (DIR, $full_directory_name) || die "Can't open $full_directory_name\n";
	while (my $file = readdir(DIR)) {
	  next unless $file =~ /.faa$/;
	  my $full_file_name = File::Spec->catfile($full_directory_name, $file);
	  system ("cat $full_file_name") == 0 || die "Could not read $full_file_name\n";
	  
	}
	close(DIR);
}

close (INFILE);


exit(0);

######################## S U B R O U T I N E S ############################

sub _check_params {
    my $opts = shift;
    pod2usage( -verbose => 2 ) if ( $opts->{help} || $opts->{'?'} );

    #	pod2usage( -verbose => 1 ) unless ( $opts->{'mandetory'});

}
