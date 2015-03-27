# $Id$
# Perl module for SeqToolBox::DB::irefindex
# Author: Malay <malay@bioinformatics.org>
# Copyright (c) 2013 by Malay. All rights reserved.
# You may distribute this module under the same terms as perl itself


##-------------------------------------------------------------------------##
## POD documentation - main docs before the code
##-------------------------------------------------------------------------##


=head1 NAME

SeqToolBox::DB::irefindex  - Module to parse iRefIndex database file.

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


package SeqToolBox::DB::irefindex;

@ISA = qw(SeqToolBox::Root);
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
	
	return $make; 
}



##-------------------------------------------------------------------------##
## METHODS
##-------------------------------------------------------------------------##


=head1 PUBLIC METHODS

=cut





=head1 PRIVATE METHODS

=cut




=head1 SEE ALSO

=head1 COPYRIGHTS

Copyright (c) 2013 by Malay <malay@bioinformatics.org>. All rights reserved.
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut


=head1 APPENDIX

=cut

1;