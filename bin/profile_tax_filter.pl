#!/usr/bin/env perl
# $Id: profile_tax_filter.pl 658 2011-07-28 18:54:29Z malay $

##---------------------------------------------------------------------------##
##  File: profile_tax_filter.pl
##       
##  Author:
##        Malay <malay@bioinformatics.org>
##
##  Description:
##     
#******************************************************************************
#* Copyright (C) 2010 Malay K Basu <malay@bioinformatics.org> 
#* This work is distributed under the license of Perl iteself.
###############################################################################

=head1 NAME

profile_tax_filter.pl - Filters a profile by given taxnomid id.

=head1 SYNOPSIS

profile_tax_filter.pl -t taxid profile_file


=head1 DESCRIPTION

The script takes a NCBI taxonomic ID and filters a profile file and creates a new profile where if any taxid in the given profile belongs to the required filtering taxid, it print 1 otherwise 0.


=head1 ARGUMENTS 

=over 4

=item B<profile_file>

The script takes a profile file as argument. A profile file is a contains two columns. The first column is ia list of taxids and the second column is a list of 0s and 1s.


=back

=head1 OPTIONS

=over 4

=item B<--taxid|-t taxid>

"taxid" is a NCBI taxid.


=head1 SEE ALSO

=head1 COPYRIGHT

Copyright (c) 2010 Malay K Basu <malay@bioinformatics.org>

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
use SeqToolBox;
use SeqToolBox::Taxonomy;
use Carp;

##---------------------------------------------------------------------------##
# Option processing
#  e.g.
#   -t: Single letter binary option
#   -t=s: String parameters
#   -t=i: Number paramters
##---------------------------------------------------------------------------##


my %options = (); # this hash will have the options

#
# Get the supplied command line options, and set flags
#

GetOptions (\%options, 
            'help|?',
            'taxid|t=s') || pod2usage( -verbose => 0 );

my $profile = $ARGV[0];

_check_params( \%options );

my $stb;
croak "Can't create taxonomy object" unless ( $stb = SeqToolBox::Taxonomy->new() );

open (FILE, $profile) || die "Can't open $profile: $!\n";

while (my $line = <FILE>) {
	next if $line =~ /^\#/;
	chomp $line;
#	print STDERR $line, "\n";
	my ($taxid, $value ) = split (/\s+/, $line);
#	print STDERR "$taxid $value\n";
	if ($stb->classify_taxon($taxid, $options{taxid})) {
		print $taxid, "\t", "1\n";
		
	}else {
		print $taxid, "\t", "0\n";
	}
}
close (FILE);


exit (0);

######################## S U B R O U T I N E S ############################

sub _check_params {
	my $opts = shift;
	pod2usage( -verbose => 2 ) if ($opts->{help} || $opts->{'?'});
	pod2usage( -verbose => 1 ) unless ( $opts->{'taxid'});
	
}