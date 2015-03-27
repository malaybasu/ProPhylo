# $Id$
# Perl module for SeqToolBox::File
# Author: Malay <malay@bioinformatics.org>
# Copyright (c) 2014 by Malay. All rights reserved.
# You may distribute this module under the same terms as perl itself

##-------------------------------------------------------------------------##
## POD documentation - main docs before the code
##-------------------------------------------------------------------------##

=head1 NAME

SeqToolBox::File  - DESCRIPTION of Object

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=cut

=head1 CONTACT

Malay <malay@bioinformatics.org>


=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

##-------------------------------------------------------------------------##
## Let the code begin...
##-------------------------------------------------------------------------##

package SeqToolBox::File;

use vars qw(@ISA);
@ISA       = qw(SeqToolBox::Root);
@EXPORT_OK = qw();
use strict;
use Carp;
use SeqToolBox::Root;

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
	my ($file) = $self->_rearrange( ["FILE"], @args );
	die "Could not find $file\n" unless ( -f $file );
	my $fh;

	if ( $file =~ /\.gz$/ ) {
		open( $fh, "gzip -d -c $file|" ) || die "Couldn't open $file";
	} elsif ( $file =~ /\.bz2$/ ) {
		open( $fh, "bzip2 -d -c $file|" ) || die "Couln't open $file\n";
	} elsif ($file =~ /\.xz$/) {
		open ($fh, "xz -d -c $file|") || die "Couldn't open $file\n";	
	} else {
		open( $fh, "$file" ) || die "Couldn't open $file\n";
	}
	$self->{'FH'} = $fh;

	return $self;
}

##-------------------------------------------------------------------------##
## METHODS
##-------------------------------------------------------------------------##

=head1 PUBLIC METHODS

=cut

sub get_fh {

	#	print STDERR "Inside fh\n";
	my $self = shift;
	if ( exists $self->{FH} ) {

		#		print STDERR "Beofore returning fh\n";
		return $self->{FH};

		#		print STDERr "After return fh\n";
	} else {
		return undef;
	}
}

=head2 close()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut


sub close {
	my $self = shift;
	if (exists $self->{FH}){
		close ($self->{FH});
	}
}

=head1 PRIVATE METHODS

=cut


sub DESTROY {

	#	my $self = shift;
	#	if (defined $self->{FH}) {
	#		close $self->{FH};
	#	}
	#	print STDERR "DESTROY CALLED\n";
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
