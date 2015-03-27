# $Id$
# Perl module for SeqToolBox::DB::BLASTDB
# Author: Malay <malaykbasu@gmail.com>
# Copyright (c) 2012 by Malay. All rights reserved.
# You may distribute this module under the same terms as perl itself

##-------------------------------------------------------------------------##
## POD documentation - main docs before the code
##-------------------------------------------------------------------------##

=head1 NAME

SeqToolBox::DB::BLAST  - Object oriented wrapper for BLAST result stored in a SQLite3 database.

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

package SeqToolBox::DB::BLASTDB;
use vars qw(@ISA);
@ISA = qw(SeqToolBox::Root);
use SeqToolBox::Root;
use SeqToolBox::DB::BLASTHit;
use Carp;
use DBI;

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
	my ( $file, $db ) = $self->_rearrange( [ "FILE", "DB" ], @args );
	$self->{_db}   = $db   || undef;
	$self->{_file} = $file || undef;
	
}

##-------------------------------------------------------------------------##
## METHODS
##-------------------------------------------------------------------------##

=head1 PUBLIC METHODS

=cut

=head2 create()

Create a blast database from the file.

	Usage   :
  	Args    :
  	Returns : 
  	
=cut

sub create {
	my ( $self, @args ) = @_;
	unless ( $self->{_db} ) { croak "Database name not found"; }
	my $db = $self->{_db};
	if     ( -s $db )         { croak "Database $db exists"; }
	unless ( $self->{_file} ) { croak "Filename not found\n;" }
	my $file = $self->{_file};
	$self->{dbh} =
	  DBI->connect( "dbi:SQLite:$db", undef, undef,
					{ AutoCommit => 0, RaiseError => 1 } )
	  or croak $DBI::errstr;
	$self->{dbh}->do("PRAGMA synchronous = OFF")
	  ;    # Make the insert faster but unsafe
	$self->{dbh}->do("PRAGMA cache_size = 200000")
	  ;    # Make the index creation faster.

	$self->{dbh}->do(
"create table blast (query text not null, subject text not null,bit_score double not null)"
	) or croak $DBI::errstr;

	$self->{dbh}->commit();
	$self->{insert_statement}
	  = $self->{dbh}->prepare('insert into blast values (?, ?, ?)')
	  or croak $DBI::errstr;
	  
	open (FILE, $file) || die "Can't open $file\n";
	while (my $line = <FILE>) {
		next if $line =~ /^\#/;
		chomp $line;
		my @f = split (/\t/, $line);
		unless (@f == 12) {croak "The BLAST file is not in -m9 or -m8 format\n";}
		$self->{insert_statement}->execute($f[0], $f[1], $f[11]);
	}  
	close (FILE);
	$self->{dbh}->commit() or croak $DBI::errstr;
	$self->{dbh}->do("create index index1 on blast (query,subject)") or croak $DBI::errstr;
	$self->{dbh}->commit();
	return 1;

}

sub get_scores {
	my ($self, @args) = @_;
	my ($q, $s) = $self->_rearrange(['Q','S'], @args);
	unless ($q && $s) {croak "Getting a score requires both the query and the subject"};
	unless ($self->{_db}) {
		croak "Could not find dbname\n";
	}
	unless ($self->{dbh}) {
		my $db = $self->{_db};
		$self->{dbh} =
	  DBI->connect( "dbi:SQLite:$db", undef, undef,
					{ AutoCommit => 0, RaiseError => 1 } )
	  or croak $DBI::errstr;
	}
	unless ($self->{select_score_query}) {
		$self->{select_score_query} = $self->{dbh}->prepare("select bit_score from blast where (query = ? and subject = ?) order by bit_score desc");
	}
	$self->{select_score_query}->execute($q, $s);
	my @row = $self->{select_score_query}->fetchrow_array();
	return @row if (@row);
	return undef;
	
}

sub get_best_score {
	my ($self, @args) = @_;
	my @scores = $self->get_scores(@args);
	my $best = 0;
	foreach my $s (@scores) {
		if ($s > $best) {
			$best = $s;
		}
	}
	return $best;
}
sub get_best_hsps {
	my ($self, $q) = @_;
	croak "Query is a mandetory option" unless $q;
	unless ($self->{dbh}) {
		my $db = $self->{_db};
		$self->{dbh} =
	  DBI->connect( "dbi:SQLite:$db", undef, undef,
					{ AutoCommit => 0, RaiseError => 1 } )
	  or croak $DBI::errstr;
	}
	unless ($self->{select_hits_query}) {
		$self->{select_hits_query} = $self->{dbh}->prepare("select subject,bit_score from blast where (query = ?) order by bit_score desc");
	}
	$self->{select_hits_query}->execute($q);
	my %seen;
	my @return;
	while (my @row =$self->{select_hits_query}->fetchrow_array()) {
		if (exists $seen{$row[0]} && $seen{$row[0]} > $row[1]) {
			next;
		}else {
			$seen{$row[0]} = $row[1];
			my $hit = SeqToolBox::DB::BLASTHit->new(-query=>$q, -subject=>$row[0], -score=>$row[1]);
			push @return, $hit;
		}
	}
	return @return;
}
=head1 PRIVATE METHODS

=cut

sub get_dbh {
	my $self = shift;
	return $self->{dbh} if ($self->{dbh});
	unless ($self->{_db}) {
		croak "Could not find dbname\n";
	}
	
		my $db = $self->{_db};
		$self->{dbh} =
	  DBI->connect( "dbi:SQLite:$db", undef, undef,
					{ AutoCommit => 0, RaiseError => 1 } )
	  or croak $DBI::errstr;
	return $self->{dbh};
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
