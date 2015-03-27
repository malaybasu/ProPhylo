# $Id: CMR.pm 394 2009-06-12 19:44:38Z malay $
# Perl module for PhyloProf::DB::CMR
# Author: Malay <malay@bioinformatics.org>
# Copyright (c) 2009 by Malay. All rights reserved.
# You may distribute this module under the same terms as perl itself

##-------------------------------------------------------------------------##
## POD documentation - main docs before the code
##-------------------------------------------------------------------------##

=head1 NAME

PhyloProf::DB::CMR  - DESCRIPTION of Object

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

package PhyloProf::DB::CMR;
@ISA = qw(PhyloProf::Root);
use PhyloProf::Profile;
use Term::ProgressBar;
use PhyloProf::Root;
use DBI;
use Carp;
use File::Spec;
use strict;
use URI;
use LWP::UserAgent;
use IO::Zlib;

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

	my ( $local, $dbdir, $remote, $website )
	  = $self->_rearrange( [ "LOCAL", "DBDIR", "REMOTE", "WEBSITE" ], @args );

	if ($dbdir) {
		$self->{_dbdir} = $dbdir;
	} elsif ( exists $ENV{JCVI_CMR_DB_DIR} ) {
		$self->{_dbdir} = $ENV{JCVI_CMR_DB_DIR};
	} else {
		$self->{_dbdir} = File::Spec->tmpdir();
	}

#	unless (-s $self->{_dbdir}) {
#		eval {
#		system ("mkdir $self);
#		};
#		if ($@) {
#			croak "Couldn't create $dbdir \n";
#		}
#	}

	if ($website) {
		$self->{_website} = $website;
	} elsif ( exists $ENV{JCVI_WEB} ) {
		$self->{_website} = $ENV{JCVI_WEB};
	} else {
		croak "JCVI_WEB not defined\n";
	}

	#
	#	if ( $local && $dbdir ) {
	#		$self->{_local} = 1;
	#		$dbdir =~ s/\/$//;
	#		$self->{_dbdir} = $dbdir;
	#
	#	} elsif ( $local && !$dbdir ) {
	#		$self->{_local} = 1;
	#		$self->{_dbdir} = $ENV{JCVI_CMR_DB_DIR}
	#		  || croak "Please set JCVI_CMR_DB_DIR\n";
	#	} else {
	#		croak "Dummy\n";
	#	}
	#
	#	if ($local) {
	#		my $dbfile = $self->{_dbdir} . '/' . "ppp_db.sqlite";
	#		if ( -s $dbfile ) {
	#			$self->{_dbh} =
	#			  DBI->connect_cached( "dbi:SQLite:dbname=$dbfile", "", "",
	#							{ RaiseError => 1, AutoCommit => 0 } )
	#			  || croak "Could not open database\n";
	#		} else {
	#			croak "Could not find the database file\n";
	#		}
	#
	#	} else {
	#		croak "Only local databas is supported at present\n";
	#	}

#	$self->{_profile_sth}
#	  = $self->{_dbh}->prepare_cached(
#'select subject_db from all_vs_all where query = ? and query != subject order by e_value'
#	  );
#	$self->{_member_sth} = $self->{_dbh}
#	  ->prepare_cached('select distinct(query) from all_vs_all where query_db = ?');
}

##-------------------------------------------------------------------------##
## METHODS
##-------------------------------------------------------------------------##

=head1 PUBLIC METHODS

=cut

=head2 get_dbdir()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut

sub get_dbdir {
	my ( $self, @args ) = @_;
	if ( $self->{_dbdir} ) {
		return $self->{_dbdir};
	} else {
		return;
	}

}

=head2 get_profile_from_blast()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut

sub get_profile_by_id {
	my ( $self, $id ) = @_;
	my %prof;

	#	$self->{_profile_sth}->execute($id);
	my $order   = 0;
	my @hitlist = $self->get_hit_list_by_id($id);
	unless (@hitlist) { return};
#	print STDERR "@hitlist\n";
	#	while ( my ($s_db) = $self->{_profile_sth}->fetchrow_array() ) {
	foreach my $s_db (@hitlist) {
		my $db = $self->get_db_by_id ($s_db);
		unless ($db) {next};
#		print STDERR "$id, \t, $s_db, "\t\n";
		if (exists $prof{$db}) {next;}
		$order++;
		$prof{$db} = $order;
	}
	return PhyloProf::Profile->new( -profile => \%prof );
}

=head2 get_hit_list_by_id()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut

sub get_hit_list_by_id {
	my ( $self, $id ) = @_;
	my $genome   = $self->get_db_by_id($id);
	my $filename = $genome . '.sqlite';
	my $fullpath = File::Spec->catfile( $self->get_dbdir(), $filename );
#	print STDERR "$fullpath\n";
	if ( -s $fullpath ) {
		my $dbh = DBI->connect_cached( "dbi:SQLite:dbname=$fullpath", "", "",
								{ RaiseError => 1, AutoCommit => 1 } );
		my $sth
		  = $dbh->prepare_cached(
"select subject_id from all_vs_all where query_id = ? and subject_id != query_id order by match_order"
		  );
		$sth->execute( $id);
		my @return;
		while (my ($value) = $sth->fetchrow_array()) {
			push @return, $value;
		}
		$sth->finish();
		$sth = undef;
	#	$dbh->disconnect(); 
		return @return;

	} else {
		$self->_download( $filename . '.gz' );
		$self->get_hit_list_by_id($id);
	}
}

=head2 get_db_by_id()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut

sub get_db_by_id {
	my ( $self, $id ) = @_;
	my $filename = 'id_file_map.sqlite';
	my $fullpath = File::Spec->catfile( $self->get_dbdir(), $filename );
	if ( -s $fullpath ) {
		my $dbh = DBI->connect_cached( "dbi:SQLite:dbname=$fullpath", "", "",
								{ RaiseError => 1, AutoCommit => 1 } );
		my $sth
		  = $dbh->prepare_cached("select genome from id_file_map where id = ?");
		$sth->execute($id);
		my $return;
		my $count = 0;
		while ( my ($genome) = $sth->fetchrow_array() ) {
			$count++;
			if ( $count > 1 ) {
				croak "More than one entry found for $id\n";
			}
			$return = $genome;
		}
		carp "Genome for $id not found\n" unless $return;
		$sth->finish();
		$sth = undef;
	#	$dbh->disconnect();
		return $return;

	} else {
		$self->_download( $filename . '.gz' );
		return $self->get_db_by_id($id);
		
	}
}

=head2 get_ids_by_db()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut

sub get_ids_by_db {
	my ( $self, $db ) = @_;
	my $filename = $db . '.sqlite';
	my $fullpath = File::Spec->catfile( $self->get_dbdir(), $filename );
	if ( -s $fullpath ) {
		my $dbh = DBI->connect_cached( "dbi:SQLite:dbname=$fullpath", "", "",
								{ RaiseError => 1, AutoCommit => 1 } );

		my $sth = $dbh->prepare_cached("select distinct(query_id) from all_vs_all");
		$sth->execute();
		my @return;
		while (my ($value) = $sth->fetchrow_array()) {
			push @return, $value;
		}
		
		$sth->finish();
		$sth = undef;
	#	$dbh->disconnect();
		return @return;
	} else {
		$self->_download( $db . '.sqlite.gz' );
		return $self->get_ids_by_db($db);
	}
}


sub get_des_by_id {
	my ($self, $id) = @_;
	my $filename = "id_des.sqlite";
	my $fullpath = File::Spec->catfile( $self->get_dbdir(), $filename );
	if ( -s $fullpath ) {
		my $dbh = DBI->connect_cached( "dbi:SQLite:dbname=$fullpath", "", "",
								{ RaiseError => 1, AutoCommit => 1 } );
		my $sth
		  = $dbh->prepare_cached("select des from id_des where id = ?");
		$sth->execute($id);
		my $return;
		my $count = 0;
		while ( my ($genome) = $sth->fetchrow_array() ) {
			$count++;
			if ( $count > 1 ) {
				croak "More than one entry found for $id\n";
			}
			$return = $genome;
		}
		carp "Des for $id not found\n" unless $return;
		$sth->finish();
		$sth = undef;
		#$dbh->disconnect();
		return $return;

	} else {
		$self->_download( $filename . '.gz' );
		return $self->get_des_by_id($id);
		
	}
	
}
=head1 PRIVATE METHODS

=cut

sub DESTROY {
#	my $self = shift;
#	$self->{_member_sth}->finish();
#	$self->{_member_sth} = undef;
#	$self->{_profile_sth}->finish();
#	$self->{_profile_sth} = undef;
#	$self->{_dbh}->disconnect();
}

sub _download {
	my ( $self, $file ) = @_;
	my $website = $self->{_website};

	my $path = URI->new_abs( $file, $website )->as_string();
#	print STDERR "$path\n";
#	die;
	
#	print STDERR $self->get_dbdir(),"\n";
	my $outfilename = File::Spec->catfile( $self->get_dbdir(), $file );
	
#	print STDERR "Filename: $outfilename\n";
#	die;
	open my $outfile, ">$outfilename" || die "Can't create $file: $!";

	#print STDERR "Downloading Taxonomy file from NCBI website.\n";
	my $bar = Term::ProgressBar->new(
						  { name => $file, count => 1024, ETA => 'linear' } );
	my $output        = 0;
	my $target_is_set = 0;
	my $next_so_far   = 0;

	my $ua = LWP::UserAgent->new();
	my $res = $ua->get(
		$path,
		":content_cb" => sub {
			my ( $chunk, $response, $protocol ) = @_;
			#print STDERR $response, "\n";
			if ($response->is_error) {
				die "Could not download $file ", $response->status_line;
			}
			unless ($target_is_set) {
				if ( my $cl = $response->content_length ) {
					$bar->target($cl);
					$target_is_set = 1;

				} else {
					$bar->target( $output + 2 * length $chunk );
				}
			}
			$output += length $chunk;
			print $outfile $chunk;

			if ( $output >= $next_so_far ) {
				$next_so_far = $bar->update($output);
			}

		}
	);

	if ($res->is_error) {
		close $outfile;
		eval { unlink "$outfilename"};
		croak "\nCould not download $path ", $res->status_line, "\n";
	}
	

	$bar->target($output);
	$bar->update($output);


	close $outfile;
	$self->_unzipfile($file);
}

=head2 _unzipfile()

Describe your function here

	Usage   :
  	Args    :
  	Returns : 
  	
=cut

sub _unzipfile {
	my ( $self, $file ) = @_;
	my $outfilename;
	if ( $file =~ /(\S+)\.gz/ ) {
		$outfilename = File::Spec->catfile( $self->get_dbdir(), $1 );
	} else {
		croak "Can't find $file\n";
	}
	my $infile = File::Spec->catfile( $self->get_dbdir(), $file );
	my $fh = IO::Zlib->new( $infile, "rb" ) || croak "Can't open $infile\n";
	open my $out, ">$outfilename" || croak "Can't open $outfilename\n";
	while ( my $chunk = <$fh> ) {
		print $out $chunk;
	}
	close $out;
	$fh->close();
	unlink($infile) || croak "Can't remove zipped $infile\n";

}

=head1 SEE ALSO

=head1 COPYRIGHTS

Copyright (c) 2009 by Malay <malay@bioinformatics.org>. All rights reserved.
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

=head1 APPENDIX

=cut

1;
