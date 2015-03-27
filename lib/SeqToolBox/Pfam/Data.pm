# $Id$
# Perl module for SeqToolBox::Pfam::Data
# Author: Malay <malay@bioinformatics.org>
# Copyright (c) 2014 by Malay. All rights reserved.
# You may distribute this module under the same terms as perl itself

##-------------------------------------------------------------------------##
## POD documentation - main docs before the code
##-------------------------------------------------------------------------##

=head1 NAME

SeqToolBox::Pfam::Data - Parses PFAM domain data
(ftp://ftp.sanger.ac.uk/pub/databases/Pfam/current_release/Pfam-A.hmm.dat.gz).

=head1 SYNOPSIS

	my $obj = SeqToolBox::Pfam::Data->new("Pfam-A.hmm.dat.gz");

=head1 DESCRIPTION

Parses and create data structure for Pfam domain data.

=cut

=head1 CONTACT

Malay <malay@bioinformatics.org>


=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal
methods are usually preceded with a _

=cut

##-------------------------------------------------------------------------##
## Let the code begin...
##-------------------------------------------------------------------------##

package SeqToolBox::Pfam::Data;

use vars qw(@ISA);
@ISA = qw(SeqToolBox::Root);
use SeqToolBox::Root;
use strict;
use Carp;

#use Data::Dumper;

##------------------------------------------------------------------------##
## GLOBALS
##------------------------------------------------------------------------##

my %data;    # Holds parsed data

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
	$self->_parse_file(@args);
	return $self;
}

##-------------------------------------------------------------------------##
## METHODS
##-------------------------------------------------------------------------##

=head1 PUBLIC METHODS

=cut

=head2 get_id_from_acc()

Given a PFAM accession, it return its ID ("textual name");

	Usage   : my $id = $pfam_obj->get_id_from_acc("PF00569.12")
  	Args    : Pfam acc
  	Returns : PFAM ID. Returns "ZZ" for the earlier call
  	
=cut

sub get_id_from_acc {
	my ( $self, $acc ) = @_;
	return exists $data{$acc}->{ID} ? return $data{$acc}->{ID} : undef;
}

=head2 get_des_from_acc()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut

sub get_des_from_acc {
	my ( $self, $acc ) = @_;
	return exists $data{$acc}->{DE} ? return $data{$acc}->{DE} : undef;
}

=head2 get_domain_type_from_acc()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut

sub get_domain_type_from_acc {
	my ( $self, $acc ) = @_;
	return exists $data{$acc}->{TP} ? return $data{$acc}->{TP} : undef;
}

=head2 get_clan_from_acc()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut

sub get_clan_from_acc {
	my ( $self, $acc ) = @_;
	return exists $data{$acc}->{CL} ? return $data{$acc}->{CL} : undef;
}


=head2 get_length_from_acc()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut


sub get_length_from_acc {
	my ($self,$acc) = @_;
	return exists $data{$acc}->{ML} ? return $data{$acc}->{ML} : undef;
}

=head1 PRIVATE METHODS

=cut

=head2 _parse_file()

Parses PFAM data file.

	Usage   : $self->_parse_file(<FILENAME>)
  	Args    : PFAM data file. No need to uncompress.
  	Returns : None. Fills up the internal data structure.

=cut

sub _parse_file {
	my ( $self, @args ) = @_;

	#print STDERR "@args\n";
	my ($file) = $self->_rearrange( ["FILE"], @args );

	#print STDERR $file, "\n";
	croak "File $file not found" unless ( -f $file );
	my $fh;

	if ( $file =~ /\.gz$/ ) {
		open( $fh, "gzip -d -c $file |" ) || croak "Could not open $file\n";
	} elsif ( $file =~ /\.bzip2$/ ) {
		open( $fh, "bzip2 -d -c $file |" ) || croak "Could not open $file\n";
	} else {
		open( $fh, $file ) || croak "Could not open $file\n";
	}

	#my ($id, $ac, $de, $ga, $tp, $ml);
	my $temp_data;
	while ( my $line = <$fh> ) {
		if ( $line =~ /^\/\/$/ ) {
			if ( $temp_data->{AC} ) {
				foreach my $key ( keys %{$temp_data} ) {
					next if $key eq "AC";
					$data{ $temp_data->{AC} }->{"$key"} = $temp_data->{"$key"};
				}
				$temp_data = undef;
			} else {
				croak "Accession is undefined. That\'s strange";
			}
		} elsif ( $line =~ /^\#\s+STOCKHOLM/ ) {
			next;
		} else {
			chomp $line;
			if ( $line =~ /^\#\=GF\s+(\S+)\s+(.*)/ ) {
				$temp_data->{$1} = $2;
			}

		}
	}

	#print Dumper(%data);
	close $fh;
}

=head1 SEE ALSO

=head1 COPYRIGHTS

Copyright (c) 2014 by Malay <malay@bioinformatics.org>. All rights reserved.
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

=head1 APPENDIX

=cut

1;
