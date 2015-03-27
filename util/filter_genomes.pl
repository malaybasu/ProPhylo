#!/usr/bin/env perl
# $Id: filter_genomes.pl 658 2011-07-28 18:54:29Z malay $

##---------------------------------------------------------------------------##
##  File: filter_genomes.pl
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

filter_genomes.pl - One line description.

=head1 SYNOPSIS

filter_genomes.pl [options] -o <option>


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
use File::Spec;
use SeqToolBox;
use SeqToolBox::Taxonomy;
use SeqToolBox::Seq;
use SeqToolBox::SeqDB;
use Carp;
use Data::Dumper;

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

my @dirs = @ARGV;

my $name_to_taxid;
my $name_to_genome_size;
my $taxid_to_name;
my $species_list;
my $taxonomy = SeqToolBox::Taxonomy->new();
my $name_to_type;
my $dir_count = 0;

foreach my $d (@dirs) {
	croak "$d should be directory" unless -d $d;
	++$dir_count;
	opendir( my $dir, $d ) || die "Can't open $d\n";

	while ( my $file = readdir($dir) ) {
		print STDERR $file, "\n";
		next if ( $file =~ /^\.$/ ) || ( $file =~ /^\.\.$/ );
		my $full_dir_name = File::Spec->catdir( $d, $file );
		next unless -d $full_dir_name;

		if ( $dir_count == 1 ) {
			$name_to_type->{$file} = "complete";
		} else {
			$name_to_type->{$file} = "draft";
		}
		parse_dir( $full_dir_name, $file );

	}

}

print_data();

sub print_data {
	my %print_data;

	#print STDERR Dumper($species_list);

	foreach my $sp_id ( sort keys %{$species_list} ) {
		my ( $largest_sp, $largest_size )
			= get_largest_sp_from_complete($sp_id);
		my $add_draft      = 1;
		my $reference_size = 0;

		if ( $largest_sp && $largest_size ) {

			for ( my $i = 0; $i < @{$largest_sp}; $i++ ) {
				if ( $i == 0 ) {
					$reference_size = $largest_size->[$i];
				}

				#			print STDERR $largest_sp->[$i],"\n";
				if ( $i >= 5 ) {
					$add_draft = 0;
				}
				$print_data{ $largest_sp->[$i] }
					= $largest_sp->[$i] . "\t" 
					. $sp_id . "\t"
					. $largest_size->[$i]
					. "\tcomplete\t" . "\n";

			}
		}

		next unless $add_draft;
		$largest_sp   = undef;
		$largest_size = undef;

		( $largest_sp, $largest_size )
			= get_largest_sp( $sp_id, $reference_size );
		next unless $largest_sp || $largest_size;

		for ( my $i = 0; $i < @{$largest_sp}; $i++ ) {

			#			print STDERR $largest_sp->[$i],"\n";
			$print_data{ $largest_sp->[$i] }
				= $largest_sp->[$i] . "\t" 
				. $sp_id . "\t"
				. $largest_size->[$i]
				. "\tdraft\t" . "\n";

		}

	}

	foreach my $line ( sort keys %print_data ) {
		print $print_data{$line};
	}

}

sub get_largest_sp_from_complete {

	#print STDERR "largest_sp called\n";
	my $sp_id = shift;
	my @return_sp;
	my @return_size;
	my $largest_size = 0;
	my $largest_sp;

	foreach my $sp ( keys %{ $species_list->{$sp_id} } ) {
		next if ( $name_to_type->{$sp} eq "draft" );
		my $length = $name_to_genome_size->{$sp};

		if ( $length > $largest_size ) {
			$largest_size = $length;
			$largest_sp   = $sp;
		}
	}
	return unless $largest_size;

	push @return_sp,   $largest_sp;
	push @return_size, $largest_size;

	#print STDERR "Size:\t", "@return_sp", "\n";
	foreach my $sp ( keys %{ $species_list->{$sp_id} } ) {
		next if ( $name_to_type->{$sp} eq "draft" );
		my $length = $name_to_genome_size->{$sp};
		my $diff   = ( $largest_size - $length ) / $largest_size;

		if ( $diff >= 0.1 ) {

			push @return_sp,   $sp;
			push @return_size, $length;

			#print STDERR "Loop: ", "@return_sp", "\t", $diff, "\n";
		}

	}

	return \@return_sp, \@return_size;
}

sub get_largest_sp {

	#print STDERR "largest_sp called\n";
	my $sp_id     = shift;
	my $reference = shift;
	my @return_sp;
	my @return_size;
	my $largest_size = 0;
	my $largest_sp;

	if ( $reference == 0 ) {
		foreach my $sp ( keys %{ $species_list->{$sp_id} } ) {
			next if ( $name_to_type->{$sp} eq "complete" );
			my $length = $name_to_genome_size->{$sp};

			if ( $length > $largest_size ) {
				$largest_size = $length;
				$largest_sp   = $sp;
			}
		}
		return unless $largest_size;

		push @return_sp,   $largest_sp;
		push @return_size, $largest_size;
	} else {
		$largest_size = $reference;
	}

	#print STDERR "Size:\t", "@return_sp", "\n";
	foreach my $sp ( keys %{ $species_list->{$sp_id} } ) {
		next if ( $name_to_type->{$sp} eq "complete" );
		my $length = $name_to_genome_size->{$sp};
		my $diff   = ( $largest_size - $length ) / $largest_size;

		if ( $diff >= 0.1 ) {

			push @return_sp,   $sp;
			push @return_size, $length;

			#print STDERR "Loop: ", "@return_sp", "\t", $diff, "\n";
		}

	}

	return \@return_sp, \@return_size;

}

sub parse_dir {
	my ( $dir_name, $sp_name ) = @_;

	my $count     = 0;
	my $seqlength = 0;
	my $taxid;
	my $species_id;

	opendir( my $dir, $dir_name ) || die "Can't open $dir_name\n";
	while ( my $file = readdir($dir) ) {
		next unless $file =~ /\.faa$/ || $file =~ /\.gz$/;
		my $full_file_name = File::Spec->catfile( $dir_name, $file );
		my $seqdb = SeqToolBox::SeqDB->new( -file => $full_file_name );

		while ( my $seq = $seqdb->next_seq() ) {

			if ( !$taxid || !$species_id ) {
				my $gi = $seq->get_gi();
				croak "Could not get gi from $file in $dir_name" unless $gi;
				$taxid = $taxonomy->get_taxon($gi);
				$species_id = $taxonomy->collapse_taxon( $taxid, "species" );
				$count++;

				if ( !$taxid || !$species_id ) {
					print STDERR
						"ERROR: Could not get taxonomic information for $gi in $file in $dir_name, trying again...\n";
				}
			}

			$seqlength += $seq->length();
		}

	}
	close($dir);
	$name_to_taxid->{$sp_name}               = $taxid;
	$name_to_genome_size->{$sp_name}         = $seqlength;
	$species_list->{$species_id}->{$sp_name} = 1;

}

exit(0);

######################## S U B R O U T I N E S ############################

sub _check_params {
	my $opts = shift;
	pod2usage( -verbose => 2 ) if ( $opts->{help} || $opts->{'?'} );

	#	pod2usage( -verbose => 1 ) unless ( $opts->{'mandetory'});

}
