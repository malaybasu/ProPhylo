# $Id$
# Perl module for SeqToolBox::DB::BLASTHit
# Author: Malay <malaykbasu@gmail.com>
# Copyright (c) 2012 by Malay. All rights reserved.
# You may distribute this module under the same terms as perl itself


##-------------------------------------------------------------------------##
## POD documentation - main docs before the code
##-------------------------------------------------------------------------##


=head1 NAME

SeqToolBox::DB::BLAST_hit  - DESCRIPTION of Object

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


package SeqToolBox::DB::BLASTHit;
use vars qw(@ISA);
@ISA = qw(SeqToolBox::Root);
use SeqToolBox::Root;
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
	my ($q, $s, $score) = $self->_rearrange(["QUERY","SUBJECT","SCORE"], @args);
	$self->{_q} = $q || undef;
	$self->{_s} = $s || undef;
	$score =~ s/\s+//g;
	$self->{_score} = $score || undef;
	
}



##-------------------------------------------------------------------------##
## METHODS
##-------------------------------------------------------------------------##


=head1 PUBLIC METHODS

=cut


sub get_score {
	my $self = shift;
	return $self->{_score} ? $self->{_score} : undef;
}

sub get_query {
	my $self = shift;
	return $self->{_q} ? $self->{_q} : undef;
}

sub get_subject {
	my $self = shift;
	return $self->{_s} ? $self->{_s} : undef;
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