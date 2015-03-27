# $Id: Profile.pm 655 2011-07-26 23:08:57Z malay $
# Perl module for package PPP::Profile
# Author: Malay <mbasu@jcvi.org>
# Copyright (c) 2009 by Malay. All rights reserved.
# You may distribute this module under the same terms as perl itself

##-------------------------------------------------------------------------##
## POD documentation - main docs before the code
##-------------------------------------------------------------------------##

=head1 NAME

package  - DESCRIPTION of Object

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

package PhyloProf::Profile;
@ISA = qw(PhyloProf::Root);
use PhyloProf::Root;
use SeqToolBox::Taxonomy;
use Carp;
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

	#Fields;
	$self->{"_prof"}   = ();
	$self->{"_header"} = 0;
	$self->{'_yes'}    = 0;
	$self->{'_no'}     = 0;
	$self->{'_odds'}   = undef;
	$self->{'_ids'} = undef;

	#end fields;

	$self->_init(@_);

	return $self;
}

# _init is where the heavy stuff will happen when new is called

sub _init {
	my ( $self, @args ) = @_;
	my ( $file, $header, $profile, $rank, $taxonomy, $raw, $yes, $no )
		= $self->_rearrange( [ "FILE",     "HEADER", "PROFILE", "RANK",
							   "TAXONOMY", "RAW",    "YES",     "NO"
							 ],
							 @args
		);

	#	print STDERR "Inside profile @args\n";
	#	foreach my $key (keys %{$raw}) {
	#			print $key, "\t", $raw->{$key}, "\n";
	#		}
	
	if ( defined($raw) && defined($yes) && defined($no) ) {

		#		print STDERR "Inside raw\n";
		#		foreach my $key (keys %{$raw}) {
		#			print $key, "\t", $raw->{$key}, "\n";
		#		}
		$self->{_prof} = $raw;
		$self->{_yes}  = $yes;
		$self->{_no}   = $no;

		return;
	}

	if ($taxonomy) {

		#print STDERR "Taxonomy exists $taxonomy\n";
		$self->{_dbh} = $taxonomy;
	}
	if ($header) { $self->{_header} = 1 }
	if ($rank)   { $self->{_rank}   = $rank; }

	if ($file) {
		$self->_parse_file($file);

		#confess "File is a mandetory parameter\n";
	}

	if ( $profile && ref($profile) eq "HASH" ) {

		#print STDERR "hash supplied\n";
		my $yes = 0;
		my $no  = 0;

		my %hash;

		#		my $tax;
		#
		#		if ( exists $self->{_rank} ) {
		#			$tax = SeqToolBox::Taxonomy->new();
		#
		#		}

		foreach my $key ( keys %{$profile} ) {
			my $taxon = $self->_get_taxon($key);
			next unless $taxon;

			#print STDERR $taxon, "\t", $profile->{$key}, "\n";
			if ( exists $hash{$taxon} && $hash{$taxon} != 0 ) {
				next;
			}
			else {
				$hash{$taxon} = $profile->{$key};
			}

		#			if ($tax) {
		#				my $taxon = $tax->collapse_taxon( $key, $self->{_rank} );
		#
		#				unless ($taxon) {
		#					die "Could not find $rank for ", $key, "\n";
		#				}
		#
		#				if ( exists $hash{$taxon} && $hash{$taxon} != 0 ) {
		#					next;
		#				}
		#				else {
		#					$hash{$taxon} = $profile->{$key};
		#				}
		#
		#			 #			if ($f[1] != 0 && exists $hash{$f[0]} && $hash{$f[0]} == 0) {
		#			 #				$hash{ $f[0] } = $f[1];
		#			 #			}
		#			}
		#			else {
		#				$hash{$key} = $profile->{$key};
		#			}
		}

		foreach my $key ( keys %hash ) {

			if ( $hash{$key} != 0 ) {

				#				$self->{_yes}++;
				$yes++;
			}
			elsif ( $hash{$key} == 0 ) {

				#				$self->{_no}++;
				$no++;
			}
			else {

			 #			confess "Second column is $file must contain only 0 and 1\n";
			}

		}

		#		if ( $profile->{$key} != 0 ) {
		#
		#			$yes++;
		#
		#			#				print STDERR "yes $yes\n";
		#		}
		#		else {
		#			$no++;
		#		}
		#	}
		$self->{_prof} = \%hash;

		$self->{_yes} = $yes;
		$self->{_no}  = $no;
	}
	elsif ($profile && ref($profile eq "ARRAY")) {
		#print STDERR "hash supplied\n";
		my $yes = 0;
		my $no  = 0;
		my @taxon_list;

		foreach my $key ( @{$profile} ) {
			my $taxon = $self->_get_taxon($key);
			next unless $taxon;
			push @taxon_list, $taxon;

		}

		
		$self->{_prof} = \@taxon_list;

		$self->{_yes} = sclar(@taxon_list);
		$self->{_no}  = $no;
		
	}
	else {
#		croak "Could not parse profile data\n";
	}

}

##-------------------------------------------------------------------------##
## METHODS
##-------------------------------------------------------------------------##

=head1 PUBLIC METHODS

=cut

=head2 get_odds()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut

sub get_odds {
	my $self = shift;
	return $self->{_odds}
		? $self->{_odds}
		: sprintf( "%.3f",
				   ( $self->{_yes} / ( $self->{_yes} + $self->{_no} ) ) );
}

=head2 set_odds()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut

sub set_odds {
	my ( $self, $value ) = @_;

	#	TODO: check that only a number is provided in value;
	confess "value not provided\n" unless $value;
	$self->{_odds} = $value;
}

=head2 exists()

Describe your function here

	Usage   :
  	Args    : 
  	Returns : 
  	
=cut

sub is_present {
	my ( $self, $id ) = @_;
	if (ref($self->{_prof}) eq "HASH") {
		
	

	if ( $self->{_prof} && exists $self->{_prof}->{$id} ) {
		return 1;
	}
	else {
		return;
	}}
	elsif (ref($self->{_prof}) eq "ARRAY"){
		foreach my $i (@{$self->{_prof}}) {
			if ($i eq $id) {
				return 1;
			}
		}
		return;
	}else {
		return;
	}
}

=head2 is_yes()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut

sub is_yes {
	my ( $self, $id ) = @_;
	#die "$id not found" unless $id;
	if (    $self->{_prof}
		 && exists $self->{_prof}->{$id}
		 && $self->{_prof}->{$id} != 0 )
	{
		return 1;
	}
	else {
		return;
	}
}

=head2 get_total()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut

sub get_total {
	my ( $self, @args ) = @_;

	if ( exists $self->{_total} ) {
		return $self->{_total};
	}

	if ( exists $self->{_yes} && exists $self->{_no} ) {
		$self->{_total} = $self->{_yes} + $self->{_no};
		return $self->{_total};
	}
	return;
}

=head2 get_yes()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut

sub get_yes {
	my ( $self, @args ) = @_;

	if ( exists $self->{_yes} ) {
		return $self->{_yes};
	}
	else {
		return;
	}
}

=head2 get_no()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut

sub get_no {
	my ( $self, @args ) = @_;

	if ( exists $self->{_no} ) {
		return $self->{_no};
	}
	else {
		return;
	}
}

=head2 get_hash()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut

sub get_hash {
	my ( $self, @args ) = @_;

	if ( exists $self->{_prof} ) {
		return $self->{_prof};
	}
	else {
		return;
	}
}

=head1 PRIVATE METHODS

=cut

=head2 _parse_file()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut

sub _parse_file {
	my ( $self, @args ) = @_;
	my $file = $args[0];
	open( FILE, $file ) or croak "Can' open $file\n";
	my %hash;
	my $lineno = 0;

	#	my $tax;
	#
	#	if ( exists $self->{_rank} ) {
	#		$tax = SeqToolBox::Taxonomy->new();
	#	}

	while ( my $line = <FILE> ) {
		chomp $line;
		$lineno++;

		if ( $self->{_header} && $lineno == 1 ) {
			next;
		}
		if ( $line =~ /^\#/ ) { next; }
		my @f = split( /\t/, $line );

		if ( scalar(@f) != 2 ) {
			confess "$file must contain only two fields\n";
		}

		my $taxon = $self->_get_taxon( $f[0] );
		next unless $taxon;

		if ( exists $hash{$taxon} && $hash{$taxon} != 0 ) {
			next;
		}
		else {
			$hash{$taxon} = $f[1];
		}

		#		if ($tax) {
		#			my $taxon = $tax->collapse_taxon( $f[0], $self->{_rank} );
		#			unless ($taxon) { die "Could not find rank for ", $f[0], "\n"; }
		#
		#			if ( exists $hash{$taxon} && $hash{$taxon} != 0 ) {
		#				next;
		#			}
		#			else {
		#				$hash{$taxon} = $f[1];
		#			}
		#
		#			#			if ($f[1] != 0 && exists $hash{$f[0]} && $hash{$f[0]} == 0) {
		#			#				$hash{ $f[0] } = $f[1];
		#			#			}
		#		}
		#		else {
		#			$hash{ $f[0] } = $f[1];
		#		}
	}

	foreach my $key ( keys %hash ) {

		if ( $hash{$key} != 0 ) {
			$self->{_yes}++;
		}
		elsif ( $hash{$key} == 0 ) {
			$self->{_no}++;
		}
		else {

			#			confess "Second column is $file must contain only 0 and 1\n";
		}

	}

	close(FILE) || confess "$file close error\n";

 #
 #	if ( scalar( keys %hash ) != $lineno ) {
 #		carp
 #			"Could not parse $file correctly. Does it contain duplicated entries?\n";
 #	}
	$self->{_prof} = \%hash;

}

sub _get_taxon {
	my ( $self, $taxon ) = @_;
	my $collapse = 0;

	if ( $self->{_rank} ) {
		$collapse = 1;
	}

	return $taxon unless ($collapse);

	unless ( exists $self->{_dbh} ) {
		$self->{_dbh} = SeqToolBox::Taxonomy->new();

		#		croak "Taxonomy object does not exist";
	}

	my $collapsed_taxon
		= $self->{_dbh}->collapse_taxon( $taxon, $self->{_rank} );

	unless ($collapsed_taxon) {
		$collapsed_taxon = $self->{_dbh}->collapse_taxon( $taxon, "genus" );
	}

	unless ($collapsed_taxon) {
		$collapsed_taxon = $taxon;
	}

	unless ($collapsed_taxon) {
		print STDERR "[DEATH] Could not find taxon for $taxon\n";
	}

	return $collapsed_taxon ? $collapsed_taxon : undef;

}

sub get_subset {
	my ($self, $number) = 0;
	if (($number > $self->get_total) || ($number == 0)) {
		return;
	}elsif ($number == $self->get_total) {
		return $self;
	}else {
		
	}
}
=head1 SEE ALSO

=head1 COPYRIGHTS

Copyright (c) 2009 by Malay <mbasu@jcvi.org>. All rights reserved.
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

=head1 APPENDIX

=cut

1;
