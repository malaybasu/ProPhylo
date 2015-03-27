#!/usr/bin/env perl
# $Id$

##---------------------------------------------------------------------------##
##  File: make_full_taxonomic_distribution_from_dir.pl
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

make_full_taxonomic_distribution_from_dir.pl - One line description.

=head1 SYNOPSIS

make_full_taxonomic_distribution_from_dir.pl [options] -o <option>


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
use SeqToolBox::Taxonomy;
use File::Spec;


##---------------------------------------------------------------------------##
# Option processing
#  e.g.
#   -t: Single letter binary option
#   -t=s: String parameters
#   -t=i: Number paramters
##---------------------------------------------------------------------------##

my $dir = shift;
opendir(DIR, $dir) || die "Can't open $dir\n";
my @required = ("superkingdom", "phylum", "class", "order", "family", "genus");
my $taxonomy = SeqToolBox::Taxonomy->new();
print "Taxid\t", join("\t", @required), "\n";
while (my $file = readdir(DIR)) {
	#print $file,"\n";
	my $fullname = File::Spec->catfile($dir,$file);
	next unless (-d $fullname);
	next if ($file =~ /^\.$/ || $file =~ /^\.\.$/);
	my @result;
	#print STDERR $file, "\n";
	push @result, $file;
	foreach my $r(@required) {
		my $db_result = $taxonomy->collapse_taxon($file,$r);
		if (!$db_result) {
#			print STDERR "Not found for $r\n";
			push @result, "-";
		}else {
			my $name = $taxonomy->get_name ($db_result);
			if ($name) {
				push @result, $name;
				
			}else {
				push @result, "-";
			}
		}
	}
	print join("\t", @result), "\n";
	
}