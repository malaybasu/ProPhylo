#!/usr/bin/perl
# $Id: gi2taxid.pl 736 2014-07-28 18:01:56Z malay $

##---------------------------------------------------------------------------##
##  File: gi2taxid.pl
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

gi2taxid.pl - Given a GI finds its taxonomic ID.

=head1 SYNOPSIS

gi2taxid.pl <GI>


=head1 DESCRIPTION

The script find the taxonomic ID of a given GI. 


=head1 ARGUMENTS 

=over 4

=item B<GI>

This is a NCBI GI.


=back


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
            'help|?') || pod2usage( -verbose => 0 );

_check_params( \%options );

my $gi = $ARGV[0];
#print STDERR $gi;
croak "Gi not given" unless $gi;
my $taxon = SeqToolBox::Taxonomy->new();
my $id = $taxon->get_taxon($gi);

print $id, "\n" if $id;



######################## S U B R O U T I N E S ############################

sub _check_params {
	my $opts = shift;
	pod2usage( -verbose => 2 ) if ($opts->{help} || $opts->{'?'});
#	pod2usage( -verbose => 1 ) unless ( $opts->{'mandetory'});
	
}



exit (0);