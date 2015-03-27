#/usr/lib/perl -w
# $Id: install_db.pl 333 2009-01-26 15:19:06Z malay $

##---------------------------------------------------------------------------##
##  File: install_db.pl
##
##  Author:
##        Malay <mbasu@jcvi.org>
##
##  Description:
##		This scripts installs data from the CMR database to the local SQLite
##		istallation. Optionally, it can use a local file dump to populate the
##		database.
##	TODO:
##		Put the data download from the CMR website in place.
##
#******************************************************************************
#* Copyright (C) 2009 Malay K Basu <mbasu@jcvi.org>
#* This work is distributed under the license of Perl iteself.
###############################################################################

=head1 NAME

install_db.pl - Script to populate SQLite database for local use for PPP.

=head1 SYNOPSIS

install_db.pl -s <source dir> -d <destination dir>

=head1 DESCRIPTION

The options are:

=over 4

=item B<--source|-s /source/dir/path >

Currently the source dir path must contain the downloaded file from CMR website.
The files need not be unzipped. This script can handle already zipped files. The
files needed for populating databases are bcp_all_vs_all files.

=item B<--dest|-d /destination/dir/path >

Thd directory where the SQLite databases will be stored. Remember to add this to
"PPP_DB" environment variable before using the database through PPP modules.

=back


=head1 COPYRIGHT

Copyright (c) 2009 Malay K Basu <malay@bioinformatcs.org>

=head1 AUTHORS

Malay K Basu <mbasu@jcvi.org>

=cut

use strict;
use Getopt::Long;
use Pod::Usage;
use IO::Zlib;
use DBI;
use Carp;
#use Smart::Comments;

my $source_dir_path      = '';
my $destination_dir_path = "";
my $help                 = 0;

GetOptions(
			'help|?'     => \$help,
			'source|s=s' => \$source_dir_path,
			'dest|d=s'   => \$destination_dir_path,
) or pod2usage( -verbose => 1 );

pod2usage( -verbose => 2 ) if $help;
pod2usage( -verbose => 1 )
  unless ( $source_dir_path || $destination_dir_path );

$source_dir_path      =~ s/\/$//;
$destination_dir_path =~ s/\/$//;

my $dbname = $destination_dir_path . '/' . "ppp_db.sqlite";
if ( -s $dbname ) { unlink $dbname }
my $dbh = DBI->connect( "dbi:SQLite:dbname=$dbname", "", "",
						{ RaiseError => 1, AutoCommit => 0 } );
$dbh->do("create table all_vs_all (
			query_db text,
			query text,
			subject_db text, 
			subject text, 
			e_value numeric, 
			score numeric
			)");
$dbh->do("create table db_data (id text, sp text)");
$dbh->commit();
my $sth = $dbh->prepare ("insert into all_vs_all (query_db, query, subject_db, subject,e_value,score) values (?,?,?,?,?,?)");
my $sth1 = $dbh->prepare ("insert into db_data (id, sp) values(?,?)");

my $db_id_file = $source_dir_path.'/'."bcp_db_data.gz";
croak "$db_id_file not found\n" unless (-s $db_id_file);
my $fh = IO::Zlib->new();
$fh->open($db_id_file, "rb") || croak "Can't open $db_id_file\n";
populate_tables($fh, $dbh, $sth1,$db_id_file,[0,1]);
$fh->close();
make_indices ($dbh, "db_data",["sp"]);


#create_db($dbname,"data_id",[db_data_])

#create_db($dbh, [locus,acc,logp,match_len,db_id_locus] );
my $basename = "bcp_all_vs_all";

opendir( DIR, $source_dir_path ) || die "Can't open $source_dir_path\n";

while ( my $file = readdir(DIR) ) {
	next unless $file =~ /^$basename(.)*\.gz$/;

	#print STDERR $file, "\n";
	my $fullname = $source_dir_path . '/' . $file;
	print STDERR $fullname, "\n";
	unless ( -s $fullname ) {
		carp("Can't find $fullname\n");
		next;
	}
	my $fh = IO::Zlib->new();
	$fh->open($fullname,"rb") || die "Can't open $fullname\n";
	populate_tables($fh, $dbh, $sth,$fullname,[9,1,10,2,3,6],3,\&log10  );
	$fh->close();

}

make_indices ($dbh, "all_vs_all", ["query_db", "query"]);

close DIR;
$sth->finish();
$sth1->finish();
$dbh->commit();
$dbh->disconnect();



sub make_indices {
	my ($d, $table, $indexes) = @_;
	#print STDERR "Make index called\n";
	if ($indexes) {
#		print STDERR "Index present\n";
		my $index_name = $table.'_idx';
		
		my $sql = "create index $index_name on " . $table . '('
		  . join( ",", @{$indexes} ) . ')';
#		 print STDERR "$sql\n";
		$d->do($sql);
		$d->commit();
	}
}

#sub create_db {
#	my ( $fh,$field_names, $col_index, $indexes ) = @_;
#
#	#$archive->extract($file);
#	$file =~ /(\S+)\.dmp/;
#	my $base   = $1;
#	my $dbname = $taxdb . '/' . $base . '.db';
#	if ( -s $dbname ) { unlink $dbname }
#	my $dbh = DBI->connect( "dbi:SQLite:dbname=$dbname", "", "",
#							{ RaiseError => 1, AutoCommit => 0 } );
#	my $sql
#	  = 'create table ' . $base . '(' . join( ",", @{$field_names} ) . ')';
#	print STDERR $sql, "\n";
#	$dbh->do($sql);
#	my $num = scalar( @{$field_names} );
#	$sql = 'insert into ' . $base . '('
#	  . join( ",", @{$field_names} )
#	  . ') values('
#	  . join( ",", split( //, "?" x $num ) ) . ')';
#	print STDERR $sql, "\n";
#	my $sth = $dbh->prepare($sql);
#	populate_tables( $fh, $dbh, $sth, $file, $col_index );
#
#	if ($indexes) {
#		$sql = 'create index index1 on ' . $base . '('
#		  . join( ",", @{$indexes} ) . ')';
#		  print STDERR "$sql\n";
#		$dbh->do($sql);
#		$dbh->commit();
#	}
##	print STDERR "$sql\n";
##	my $sth1 = $dbh->prepare($sql);
##	$sth1->execute();
#	$sth->finish;
#	$sth = undef;
##	$sth1->finish;
##	$sth1 = undef;
#	$dbh->disconnect;
#
#	#unlink $file;
#}
#
#sub create_tables {
#	my $h = shift;
#	$h->
#}
#

sub populate_tables {
	my ( $fh, $d, $s, $file,$col, $transform_field, $function) = @_;

	#open my $fh, "$file" or die "Can't open $file: $!";
	my $count = 0;
	print STDERR "Loading $file...";
	while ( my $line = <$fh> ) {    ### Loading...  done
		chomp $line;
		my @f;
#		print STDERR "Fields: @f\n";
		if ( $line =~ /\|/ ) {
			$line =~ s/\|$//;
			@f = split( /\|/, $line );
		}
		else {
			@f = split( /\t/, $line );
		}
		my @values;
		for (my $i = 0; $i < @f; $i++) {
#		foreach my $i (@f) {
			$f[$i] =~ s/^\s+//;
			$f[$i] =~ s/\s+$//;
			if (defined($transform_field) && $i == $transform_field) {
				$f[$i] = $function->($f[$i]);
			}
			my $v = $f[$i] ? $f[$i] : "";
			push @values, $f[$i];
		}
		my @required;
		if ($values[1] eq $values[2]) {next;}
		
		foreach my $i ( @{$col} ) {
			if ( defined $values[$i] ) {
				push @required, $values[$i];
			}
			else {
				die "Required col missing in table $file\n";
			}
		}

		#print STDERR "@required\n";
		$s->execute(@required);
		if ( $count >= 1000000 ) {
			$d->commit();
			$count = 0;
		}
		else {
			$count++;
		}

	}
	print STDERR "done.\n";
	$d->commit;

	#close ($fh);
}
sub log10 {
#	print STDERR "logzero $_[0]\n";
	if ($_[0] == 0) {
		return -50000;
	}
	return sprintf "%.3f",log($_[0])/log(10);
}
