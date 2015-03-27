# $Id: BlastResult.pm 635 2011-06-09 18:27:51Z malay $
# Perl module for PPP::BlastResult
# Author: Malay <mbasu@jcvi.org>
# Copyright (c) 2009 by Malay. All rights reserved.
# You may distribute this module under the same terms as perl itself

##-------------------------------------------------------------------------##
## POD documentation - main docs before the code
##-------------------------------------------------------------------------##

=head1 NAME

PPP::BlastResult  - DESCRIPTION of Object

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=cut

=head1 CONTACT

Malay <mbasu@jcvi.org>


=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

##-------------------------------------------------------------------------##
## Let the code begin...
##-------------------------------------------------------------------------##

package PhyloProf::BlastResult;
@ISA = qw(PhyloProf::Root);
use PhyloProf::Root;
use PhyloProf::Profile;
use Carp;
use SeqToolBox::Taxonomy;
use strict;

##-------------------------------------------------------------------------##
## Constructors
##-------------------------------------------------------------------------##

=head1 CONSTRUCTOR

=head2 new()

=cut

sub new {
	my $class = shift;
	my $self  = {};
	bless $self, ref($class) || $class;

	#Fields
	$self->{_ids}    = undef;
	$self->{_scores} = undef;

	#end fields;
	$self->_init(@_);

	return $self;
}

# _init is where the heavy stuff will happen when new is called

sub _init {
	my ( $self, @args ) = @_;
	my ( $data, $value, $sorted, $taxonomy )
		= $self->_rearrange( [ "DATA", "VALUE", "SORTED", "TAXONOMY" ], @args );

	#	print STDERR keys (%{$data}), "\n";
	if ( ref $data eq "HASH" ) {
		croak("Value must be provided when providing a hash") unless $value;

		if ( $value eq "e-value" ) {
			my @ids = sort { $data->{$a} <=> $data->{$b} } keys %{$data};

			#			print STDERR "@ids\n";
			$self->{_ids} = \@ids;

			#						print STDERR "@{$self->{_ids}}", "\n";
			#			print STDERR @{%{$data}}{qw/id1/};

			my @scores;

			foreach my $i (@ids) {
				push @scores, $data->{$i};
			}

			#			 = @{ %{$data} }{@ids};

			#						print STDERR "@scores\n";
			$self->{_scores} = \@scores;

			#			print STDERR "@{$self->{_scores}}", "\n";
		} elsif ( $value eq "score" ) {
			my @ids = sort { $data->{$b} <=> $data->{$a} } keys %{$data};
			$self->{_ids} = \@ids;
			my @scores;

			foreach my $i (@ids) {
				push @scores, $data->{$i};
			}

			#			my @scores = \@{ %{$data} }{@ids};
			$self->{_scores} = \@scores;
		} else {
			croak "Value can only be e-value or score\n";
		}
	}

	elsif ( ref $data eq "ARRAY" ) {
		croak "The array data can only be used with sorted toggle"
			unless $sorted;
		$self->{_ids} = $data;

	}

	else {
		confess "Data is not in correct format\n";
	}

	if ($taxonomy) {
		$self->{taxonomy} = $taxonomy;
	}

}

##-------------------------------------------------------------------------##
## METHODS
##-------------------------------------------------------------------------##

=head1 PUBLIC METHODS

=cut

=head2 get_ids()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut

sub get_ids {
	my $self = shift;
	if   ( exists $self->{_ids} ) { return @{ $self->{_ids} }; }
	else                          { return; }
}

sub get_profile {
	my $self = shift;
	my %hash;
	my $yes   = 0;
	my $no    = 0;
	my $array = 0;

	unless ( $self->{_scores} ) {
		$array = 1;
	}
	my @scores;

	unless ($array) {
		@scores = @{ $self->{_scores} };
	}
	my @ids = @{ $self->{_ids} };
	my $tax;

	unless ( exists $self->{taxonomy} ) {
		croak "Taxonomy does not exists in Blastresult\n";
		$tax = SeqToolBox::Taxonomy->new();

	}

	#	print STDERR "In Blastresult\n";
	#	print STDERR "@ids\n";
	#	print STDERR "@scores\n";
	#	print STDERR "Id taxon data\n";
	my @taxon_array;
	
	if ($array) {

		for ( my $i = 0; $i < @ids; $i++ ) {
			my $taxon;

			if ($tax) {
				$taxon = $tax->get_taxon( $ids[$i] );
			} else {
				$taxon = $self->{taxonomy}->{ $ids[$i] };
			}
			next unless ($taxon);
			push @taxon_array, $taxon;
			#		print STDERR $ids[$i], "\ttaxon: ", $taxon, "\n";
			if ( exists $hash{$taxon} ) {
				next;
			}

			#		print STDERR $ids[$i], "\ttaxon: ", $taxon, "\n";
			$hash{$taxon} = $i + 1;
			$yes++;
		}
	} else {

		for ( my $i = 0; $i < @scores; $i++ ) {
			my $taxon;

			if ($tax) {
				$taxon = $tax->get_taxon( $ids[$i] );
			} else {
				$taxon = $self->{taxonomy}->{ $ids[$i] };
			}
			next unless ($taxon);
			push @taxon_array, $taxon;
			#		print STDERR $ids[$i], "\ttaxon: ", $taxon, "\n";
			if ( exists $hash{$taxon} ) {
				next;
			}

			#		print STDERR $ids[$i], "\ttaxon: ", $taxon, "\n";
			$hash{$taxon} = $i + 1;
			$yes++;
		}
	}
#	my $prof
#		= PhyloProf::Profile->new( -raw => \%hash, -yes => $yes, -no => $no );
	my $prof = PhyloProf::Profile->new(-raw=>\@taxon_array, -yes=>$yes, -no =>$no);	

	#	my $hash = $prof->get_hash();
	#	print STDERR "Profile data\n";
	#	foreach my $i (keys %{$hash}) {
	#		print STDERR $i, "\t", $hash{$i}, "\n";
	#	}
	return $prof;
}

=head1 PRIVATE METHODS

=cut

=head1 SEE ALSO

=head1 COPYRIGHTS

Copyright (c) 2009 by Malay <mbasu@jcvi.org>. All rights reserved.
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

=head1 APPENDIX

=cut

1;
