# $Id: ppp.pm 692 2012-07-12 20:38:27Z malay $
# Perl module for package
# Author: Malay <mbasu@jcvi.org>
# Copyright (c) 2009 by Malay. All rights reserved.
# You may distribute this module under the same terms as perl itself

##-------------------------------------------------------------------------##
## POD documentation - main docs before the code
##-------------------------------------------------------------------------##

=head1 NAME

PPP::Algorthm::ppp  - DESCRIPTION of Object

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

package PhyloProf::Algorithm::ppp;
use base "PhyloProf::Root";
use Math::Cephes qw(bdtrc);
use Carp;
use SeqToolBox::Taxonomy;
use strict;
use PhyloProf::Root;
use Data::Dumper;
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
	$self->_init(@_);
	return $self;
}

# _init is where the heavy stuff will happen when new is called

sub _init {
	my ( $self, @args ) = @_;
	my ( $profile1, $profile2, $prob, $rank, $taxonomy, $dup )
		= $self->_rearrange( [ "PROF1",    "PROF2", "PROB", "RANK",
							   "TAXONOMY", "DUP"
							 ],
							 @args
		);

	#	  = $self->_rearrange( [ "PROFILE1", "PROFILE2" ], \@args );
	if ($dup) {
		$self->{_dup} = 1;
	}

	if ($taxonomy) {
		$self->{_dbh} = $taxonomy;
	}
	unless ( $profile1 || $profile2 ) { croak "Parameter is undefined\n" }

	unless (    $profile1->isa("PhyloProf::Profile")
			 || $profile2->isa("PhyloProf::Profile") )
	{
		croak "Parameter mismatch\n";
	}

	#	print STDERR ref($profile1), "\n";
	$self->{_prof1} = $profile1;
	$self->{_prof2} = $profile2;
	#print STDERR Dumper ($profile1);
#	print STDERR Dumper ($profile2);
#	die;

	if ($prob) {
		$self->{_prob} = $prob;
	}

	if ($rank) {
		$self->{_rank} = $rank;
	}

	#	my %taxon_cache = ();
	#	$self->{_taxon_cache} = \%taxon_cache;
}

##-------------------------------------------------------------------------##
## METHODS
##-------------------------------------------------------------------------##

=head1 PUBLIC METHODS

=cut

=head2 get_match_score()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut

sub get_match_score {
	my $self   = shift;
	my $score  = 1;
	my $number = 0;
	my $yes    = 0;
	my $p;
	my $max_yes = $self->{_prof1}->get_yes();

	if ( exists $self->{_prob} ) {
		$p = $self->{_prob};
	} else {
		$p = $self->{_prof1}->get_yes() / $self->{_prof1}->get_total();
	}
	my $prof = $self->{_prof2}->get_hash();
#	print Dumper($prof);
	my @target_profile_data;

	if ( $prof && ref($prof) eq "HASH" ) {
		@target_profile_data
			= sort { $prof->{$a} <=> $prof->{$b} } keys %{$prof};

	} elsif ( $prof && ref($prof) eq "ARRAY" ) {
		@target_profile_data = @{$prof};
	}
#	print STDERR join("\n", @target_profile_data),"\n";

	my $best_yes    = 0;
	my $best_number = 0;
	my $best_depth  = 0;

	#print STDERR "In algorithm\n";
	#	print STDERR "Probab: $p\n";

	#	my $tax;
	#	if ($self->{_rank}) {
	#		$tax = SeqToolBox::Taxonomy->new();
	#	}
	my %seen;

	for ( my $i = 0; $i < @target_profile_data; $i++ ) {
			#last if $i >1;
		#		print STDERR "In PPP: ", $key, "\n";

		#		my $t = $key;
		my $t = $target_profile_data[$i];

		my $taxon = $self->_get_taxon($t);

#		print STDERR "Probab: $p Taxon: $t\t", $taxon, "\n";
		die "Taxon not found" unless $taxon;
		my $key = $taxon;

		#		if ($tax) {
		#			my $taxon = $tax->collapse_taxon( $key, $self->{_rank} );
		#			unless ($taxon) { die "Could not find rank for $key\n";}
		#			$key = $taxon;
		#		}
		#

		if ( exists $seen{$key} ) {
			unless ( $self->{_dup} ) {
				next;
			}

			if ( $self->{_dup} && $seen{key} >= 2 ) {
				next;
			}
			
			if ($self->{_dup}) {
				$seen{key}++;
			}

		} else {
			#print STDERR "Taxon: $key is absent\n";
			$seen{$key}++;
		}
		#print STDERR "Taxon: $key\n";
		if ( $self->{_prof1}->is_present($key) ) {
			$number++;

		}

		if ( $self->{_prof1}->is_yes($key)) {
			#print STDERR "Inside is yes\n";
			if ( $self->{_dup} && $seen{key} == 2) {
			}else {
			$yes++;
			}

			#			$self->{positives}->{}
		}

		if ( $yes > $max_yes ) {
			last;
		}
		my $answer = bdtrc( $yes - 1, $number, $p );

		#		print STDERR "$yes\t$number\t$answer\t$p","\n";
		if ( $answer < $score ) {

			#$best_depth = $prof->{$t};
			#			$best_depth = $self->_get_depth(\@target_profile_data, $t);
			$best_depth  = $i + 1;
			$score       = $answer;
			$best_yes    = $yes;
			$best_number = $number;
			next;
		}

		if ( $answer <= 0 ) {
			last;
		}
	}
#	print "Scores", $score, $best_yes, $best_number, $best_depth, $p;
	return $score, $best_yes, $best_number, $best_depth, $p;
}

sub _get_depth {
	my ( $self, $array, $value ) = @_;

	foreach ( my $i = 0; $i < @{$array}; $i++ ) {
		if ( $array->[$i] eq $value ) {
			return $i;
		}
	}
}

#sub get_2d_match_score {
#	my $self = shift;
#	my $score = 1;
#	my $number = 0;
#	my $yes = 0;
#	my $p;
#
#
#	if (exists $self->{_prob}) {
#		$p = $self->{_prob};
#	}else {
#		$p = $self->{_prof1}->get_yes()/$self->{_prof1}->get_total();
#	}
#	my $prof = $self->{_prof2}->get_hash();
#	my $best_yes = 0;
#	my $best_number = 0;
#	my $best_depth = 0;
#	#print STDERR "In algorithm\n";
##	print STDERR "Probab: $p\n";
#
##	my $tax;
##	if ($self->{_rank}) {
##		$tax = SeqToolBox::Taxonomy->new();
##	}
#	my %seen;
#
#	foreach my $key (sort {$prof->{$a} <=> $prof->{$b}} keys %{$prof}) {
#
##		print STDERR "In PPP: ", $key, "\n";
#
#		my $t = $key;
#
#		my $taxon = $self->_get_taxon($key);
##		print STDERR "Probab: $p Taxon: ", $taxon, "\n";
#		next unless $taxon;
#		$key = $taxon;
##		if ($tax) {
##			my $taxon = $tax->collapse_taxon( $key, $self->{_rank} );
##			unless ($taxon) { die "Could not find rank for $key\n";}
##			$key = $taxon;
##		}
##
#		if (exists $seen{$key}) {
#			next;
#		}else {
#			$seen{$key} = 1;
#		}
#
#		if ($self->{_prof1}->is_present($key)) {
#			$number++;
#
#		}
#		if ($self->{_prof1}->is_yes($key)) {
#			$yes++;
#		}
#		my $answer = bdtrc ($yes - 1, $number, $p);
##		print STDERR "$yes\t$number\t$answer\t$p","\n";
#		if ($answer < $score ) {
#			$best_depth = $prof->{$t};
#			$score = $answer;
#			$best_yes = $yes;
#			$best_number = $number;
#			next;
#		}
#		if ($answer <= 0 ) {
#			last;
#		}
#	}
#	return $score, $best_yes, $best_number, $best_depth, $p;
#}

sub _get_taxon {
	my ( $self, $taxon ) = @_;

	#	if (exists $self->{_taxon_cache}->{$taxon}) {
	#		return $self->{_taxon_cache}->{$taxon};
	#	}
	#

	my $collapse = 0;

	if ( $self->{_rank} ) {
		$collapse = 1;
	}

	return $taxon unless ($collapse);

	unless ( exists $self->{_dbh} ) {

		#$self->{_dbh} = SeqToolBox::Taxonomy->new();
		croak "Taxonomy does not exist\n";
	}

	my $collapsed_taxon
		= $self->{_dbh}->collapse_taxon( $taxon, $self->{_rank} );

	unless ($collapsed_taxon) {

		#print STDERR "Collapseing taxon\n";
		$collapsed_taxon = $self->{_dbh}->collapse_taxon( $taxon, "genus" );
	}

	unless ($collapsed_taxon) {
		$collapsed_taxon = $taxon;
	}

	unless ($collapsed_taxon) {
		print STDERR "[DEATH] Could not find taxon for $taxon\n";

	}
	$self->{_taxon_cache}->{$taxon} = $collapsed_taxon;
	return $collapsed_taxon ? $collapsed_taxon : undef;

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
