# $Id$
# Perl module for SeqToolBox::SeqDB::FASTAIndex
# Author: Malay <malaykbasu@gmail.com>
# Copyright (c) 2012 by Malay. All rights reserved.
# You may distribute this module under the same terms as perl itself

##-------------------------------------------------------------------------##
## POD documentation - main docs before the code
##-------------------------------------------------------------------------##

=head1 NAME

SeqDB::FASTAIndex  - DESCRIPTION of Object

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

package SeqToolBox::SeqDB::FASTAIndex;
@ISA = qw(SeqToolBox::Root);
use SeqToolBox::Root;
use DBI;
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
	$self->_init(@_);
	return $self;
}

# _init is where the heavy stuff will happen when new is called

sub _init {
	my ( $self, @args ) = @_;
	my ($file) = $self->_rearrange( ['FILE'], @args );
	croak "Filename not given" unless $file;
	$self->{file} = $file;
	$self->{dbh} =
		DBI->connect( "dbi:SQLite:$file", undef, undef,
					  { AutoCommit => 0, RaiseError => 1 } )
		or croak $DBI::errstr;
		$self->{dbh}->do("PRAGMA synchronous = OFF"); # Make the insert faster but unsafe
		$self->{dbh}->do("PRAGMA cache_size = 200000"); # Make the index creation faster.
	return $self;
}

##-------------------------------------------------------------------------##
## METHODS
##-------------------------------------------------------------------------##

=head1 PUBLIC METHODS

=cut

=head2 create()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut

sub create {
	my $self = shift;
	croak "No database filehandle present" unless exists $self->{dbh};
	$self->{dbh}->do("create table data (id text not null, pos int not null)")
		or croak $DBI::errstr;
		
	$self->{dbh}->commit();
	$self->{insert_statement} = $self->{dbh}->prepare('insert into data values (?, ?)') or croak $DBI::errstr;
#	$self->{query_statement} = $self->{dbh}->prepare ('select pos from data where (id = ?)');
	return 1;

}

=head2 insert()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut


sub insert {
	my ($self, @args) = @_;
	my ($id, $pos) = $self->_rearrange(['ID','POS'], @args);
	croak "pos and id are rquired option" unless (defined($id) && defined($pos));
	unless (exists $self->{insert_statement}) {croak "No database handle present did you call create()?";}
	$self->{insert_statement}->execute($id, $pos) or croak $DBI::errstr;
}

=head2 get_pos()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut


sub get_pos {
	my ($self,$id) = @_;
	#print STDERR "Position called\n";
	my @return = $self->get_all_pos($id);
	if (@return) {
		return $return[0];
	}else {
		return undef;
	}
}
=head2 get_pos()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut


sub get_all_pos {
	my ($self,$id) = @_;
	#print STDERR "Get all pos called\n";
	unless (exists $self->{query_statement}) {
		$self->{query_statement} = $self->{dbh}->prepare ('select pos from data where id = ?') or croak $DBI::errstr;
#		$self->{dbh}->commit();
	}
	croak "where is the handle" unless exists $self->{query_statement};
	$self->{query_statement}->execute($id);
	my @result;
	while (my @row = $self->{query_statement}->fetchrow_array()) {
		if (defined($row[0])) {push @result, $row[0];}
	}
	#print STDERR "Result @result\n";
	return @result;
#	if ($all) {
#		return @result;
#	}else {
#		return $result[0];
#	}
}

=head2 commit()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut


sub commit {
	my $self = shift;
	$self->{dbh}->commit() or croak $DBI::errstr;
}


=head2 create_index()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut


sub create_index {
	my $self = shift;
	$self->{dbh}->do('create index index1 on data (id)') or die $DBI::errstr;
	$self->{dbh}->commit();
}

=head1 PRIVATE METHODS

=cut

sub DESTROY {
	my $self = shift;
	if (exists $self->{query_statment} ) {$self->{query_statement}->finish();}
	if (exists $self->{insert_statement}) {$self->{insert_statement}->finish();}
	$self->{dbh}->disconnect();
}

=head1 SEE ALSO

=head1 COPYRIGHTS

Copyright (c) 2012 by Malay <malaykbasu@gmail.com>. All rights reserved.
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

=head1 APPENDIX

=cut

1;
