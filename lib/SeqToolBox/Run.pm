# $Id$
# Perl module for SeqToolBox::Run
# Author: Malay <malaykbasu@gmail.com>
# Copyright (c) 2012 by Malay. All rights reserved.
# You may distribute this module under the same terms as perl itself


##-------------------------------------------------------------------------##
## POD documentation - main docs before the code
##-------------------------------------------------------------------------##


=head1 NAME

SeqToolBox::Run  - DESCRIPTION of Object

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


package SeqToolBox::Run;
use Carp;
use vars qw(@ISA);
@ISA = qw();
@EXPORT_OK = qw();
use strict;


##-------------------------------------------------------------------------##
## Constructors
##-------------------------------------------------------------------------##

=head1 CONSTRUCTOR

=head2 new()

=cut

sub new {   
	my $class = shift;
	my $self = {};
	bless $self, ref($class) || $class;
	$self->_init(@_);
	return $self;
}  


# _init is where the heavy stuff will happen when new is called

sub _init {
	my($self,@args) = @_;
	return $self; 
}



##-------------------------------------------------------------------------##
## METHODS
##-------------------------------------------------------------------------##


=head1 PUBLIC METHODS

=cut


sub run {
	my ($self, %args ) = @_;
	
	unless (exists $args{cmd}) {
		croak "Command not given\n";
	}
	if (exists $args{skipfile}) {
		if (-s $args{skipfile}) {
			if (exists $args{skiptxt}) {
				print STDERR $args{skiptxt}, "\n";
			}
			return 1;
		}
	}
	if (exists $args{skipdir}) {
		if ((-d $args{skipdir}) && (my $file = <$args{skipdir}/*>)) {
			if (exists $args{skiptxt}) {
				print STDERR $args{skiptxt}, "\n";
			}
			return 1;
		}
	}
	
	system ($args{cmd}) == 0 || die "Could not run $args{cmd}\n";
	
	if (exists $args{tmpfile} && $args{outfile}) {
		system ("mv $args{tmpfile} $args{outfile}" )== 0 || die "Could not rename $args{tmpfile} to $args{outfile}\n";
		
	}	
	return 1;
}


=head1 PRIVATE METHODS

=cut




=head1 SEE ALSO

=head1 COPYRIGHTS

Copyright (c) 2012 by Malay <malaykbasu@gmail.com>. All rights reserved.
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut


=head1 APPENDIX

=cut

1;