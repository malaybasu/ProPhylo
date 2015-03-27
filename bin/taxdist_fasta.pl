#!/usr/bin/env perl
# $Id: taxdist_fasta.pl 614 2011-02-15 01:15:11Z malay $

use lib '/home/mbasu/projects/SeqToolBox/lib';

##---------------------------------------------------------------------------##
##  File: hmm2profile.pl
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

##---------------------------------------------------------------------------##
## Module dependencies
##---------------------------------------------------------------------------##

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Carp;
use File::Temp;
use Carp;
use Term::ProgressBar;

unless ( $ENV{'SEQTOOLBOXDB'} ) {
	pod2usage( -verbose => 2 );
}

eval { require SeqToolBox::Taxonomy };
if ($@) {
	croak
		"This script requires Malay's toolbox. Contact him at mbasu\@jcvi.org.\n";
}

my $file = "";
my $help = "";

GetOptions( 'help|h'      => \$help,
			'file|f=s'    => \$file,

) or pod2usage( -verbose => 1 );

pod2usage( -verbose => 2 ) if $help;
pod2usage( -verbose => 1 ) unless ( $file);

my %taxonomy_list;
my $filesize     = -s $file;

if ($filesize == 0) {
	croak "Error is $file\n";
}
my $next_update1 = 0;
my $progress1 = Term::ProgressBar->new( { name   => 'Parsing IDs',
										  count  => $filesize,
										  remove => 1,
										  ETA    => 'linear'
										}
);
$progress1->max_update_rate(1);
$progress1->minor(0);

my $taxonomy = SeqToolBox::Taxonomy->new();
open( FILE, $file ) || die "Can't open $file";

while ( my $line = <FILE> ) {
	
	next unless $line =~ /^\>/;

	if ( $line =~ /gi\|(\d+)/ ) {

		my $gi = $1;
		my $taxon = $taxonomy->get_taxon($gi);

		if ($taxon) {
#			print STDERR "$gi\t$taxon ";
			unless ( exists $taxonomy_list{$taxon} ) {
				$taxonomy_list{$taxon} = 0;
#				print STDERR "$gi\t$taxon ";
			}
		}

		

	}
	my $currpos = tell(FILE);
		$next_update1 = $progress1->update($currpos)
			if $currpos >= $next_update1;
	
}
$progress1->update($filesize);

close(FILE);

foreach my $key ( sort { $a <=> $b } keys %taxonomy_list ) {
	print $key,"\n";
}

__END__

=head1 NAME

taxdist_fasta.pl - Create taxonomic distribution from a fasta file.

=head1 SYNOPSIS

taxdist_fasta.pl [options]


=head1 DESCRIPTION

This script search a fasta database to create a distribution of taxons in it.  The output file should be one of the input for hmm2profile.pl for creating a complete distribution list.

=head1 INSTALLATION

You need  Malay's SeqToolBox to run this script. If your ProPhylo distribution did not come with this library then contact Malay (mbasu@jcvi.org) for a copy of SeqToolBox. Unzip the modules in your PERL5LIB. You need to first set up the NCBI taxonomy database for using this script. For this set up an environment variable "SEQTOOLBOXDB" pointing to a directory that can store about ~1.5 GB of data. After setting up this enviornment variable, run install/update_taxonomy.pl script. This will create all the databases required for running this script.

=head1 ARGUMENTS 

=over 4

=item B<--help | -h>

Print this help message.

=item B<--file | -f>

The full path of fasta file.



=back

=head1 COPYRIGHT

Copyright (c) 2009 Malay K Basu <malay@bioinformatics.org>.

=head1 AUTHORS

Malay K Basu <malay@bioinformatics.org>

=cut
