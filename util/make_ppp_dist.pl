#!/usr/bin/env perl
# $Id: make_ppp_dist.pl 658 2011-07-28 18:54:29Z malay $

##---------------------------------------------------------------------------##
##  File: make_ppp_dist.pl
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

make_ppp_dist.pl - One line description.

=head1 SYNOPSIS

make_ppp_dist.pl [options] -o <option>


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
use Cwd;
##---------------------------------------------------------------------------##
# Option processing
#  e.g.
#   -t: Single letter binary option
#   -t=s: String parameters
#   -t=i: Number paramters
##---------------------------------------------------------------------------##

my $directory = shift;
my $blastdr = File::Spec->catdir($directory, 'blast');
die "Could not file blast subdirectory under $directory" unless (-d $blastdr);

my $zip_exe;

if (`which pbzip2`) {
	print STDERR "Found pbzip2. Will use it for faster zipping.\n";
	$zip_exe = 'pbzip2';
}elsif (`which bzip2`) {
	print STDERR "Could not find pbzip2. Using bzip2\n";
	$zip_exe = 'bzip2';
}else {
	die "Could not find pbzip2 or bzip2 in the path\n";
}


if (`which tar`) {
	print STDERR "Found tar.\n";
}else {
	die "Could not find tar in path\n";
}

my $current_dir = cwd();
print STDERR "Zipped files will be stored in $current_dir\n";

opendir (DIR, $blastdr) || die "Can't open $blastdr\n";
while (my $subdir = readdir (DIR)) {
	next if ($subdir =~ /^\.$/ || $subdir =~ /^\.\.$/);
	unless ($subdir =~ /^(\d+)$/) {
		die "Found $subdir. Directory name should be an integer corresponding to taxon id\n";
	}
	unless (-d File::Spec->catdir($blastdr, $subdir)) {
		die "$subdir is not a directory\n";
	}
	print STDERR "Found $subdir\n";
	my $output_file = $subdir.'.tar.bz2';
	my $command = "tar -c -C $blastdr $subdir | $zip_exe -c -9 >$output_file";
	
	system ("$command") == 0 || die "Could not execute: $command\n";
}

close (DIR);

exit(0);
