#!/usr/bin/perl -w
use strict;
use warnings;
use DBI;

#my $db = shift;
my $username = shift;
my $password = shift;

my $dbh =
	DBI->connect( "dbi:Sybase:dbname=common", $username, $password,
				  { RaiseError => 1 } )
	|| die "Can't connect to CMR database\n";

$dbh->do("use omnium");

# Select human-readable genome database name
my $sth = $dbh->prepare('select distinct(original_db) from db_data');

# select data from all_vs_all table for the human-readable genome database name
# provided
my $sth1 = $dbh->prepare(
	"select locus, 
		accession, 
		convert(varchar,Pvalue),
		match_len, match_order
		from all_vs_all,db_data
				where db_data.original_db = ? and 
					db_data.id = all_vs_all.db_id_locus"
);

# we want all the descript. There are are two-types of tables
my @des_query_statements;
push @des_query_statements,
	$dbh->prepare("select locus, gene_sym, com_name from ident");
push @des_query_statements,
	$dbh->prepare("select locus, gene_sym, com_name from nt_ident");

# Given an id we want to get the genome name as quickly as we can
my $all_db_handle = DBI->connect( "dbi:SQLite:dbname=id_file_map.sqlite",
								  "", "",
								  {  RaiseError => 1,
									 AutoCommit => 0
								  }
);

$all_db_handle->do("create table id_file_map (id text, genome text)");
my $all_db_statement = $all_db_handle->prepare(
						 "insert into id_file_map (id, genome) values (?,?)");

# Statement and Handle for description table
my $des_handle = DBI->connect( "dbi:SQLite:dbname=id_des.sqlite",
							   "", "",
							   {  RaiseError => 1,
								  AutoCommit => 0
							   }
);
$des_handle->do("create table id_des (id text, des text)");
my $des_sth
	= $des_handle->prepare("insert into id_des (id, des) values(?,?)");

# Main loop

$sth->execute();    # get all the unique genome names

while ( my ($locus) = $sth->fetchrow_array() ) {

	# create a sqlite database with the genome name that will hold the blast
	# hits for this genome
	my $outfile = $locus . '.sqlite';
	my $dbh2    = DBI->connect( "dbi:SQLite:dbname=$outfile", "", "",
							 { RaiseError => 1, AutoCommit => 0 } );
	$dbh2->do(
		"create table all_vs_all (
			query_id text,
			subject_id text, 
			p_value numeric, 
			match_len numeric,
			match_order numeric)"
	);

	my $sth2 = $dbh2->prepare(
		"insert into all_vs_all (query_id,subject_id, p_value, match_len, match_order) 
			values(?,?,?,?,?)"
	);

	#	print $locus, "\n";

	# get all the hits for this genome only
	$sth1->execute($locus);

	my %seen;    # to hold already seen locus

	while ( my ( $l, $acc, $p, $len, $order ) = $sth1->fetchrow_array() ) {
		$sth2->execute( $l, $acc, $p, $len, $order )
			;    # insert it into the all_vs_all table

		if ( !exists $seen{$l} )
		{        # we don't want duplicate entry to locus-db map table
			$all_db_statement->execute( $l, $locus )
				;    # insert it into the locus-db map table
			$seen{$l} = 1;
		}
	}
	$dbh2->commit();
	$dbh2->do("create index index1 on all_vs_all (query_id)");
	$dbh2->commit();
	$sth2->finish();
	$sth2 = undef;
	$dbh2->disconnect();
}    # we have created all_vs_all table for this genome get the next one

$all_db_handle->commit();
$all_db_handle->do("create index index1 on id_file_map (id)");
$all_db_handle->commit();
$all_db_statement->finish();
$all_db_statement = undef;
$all_db_handle->disconnect();

populate_descriptions();

$sth1->finish();
$sth1 = undef;
$sth->finish();
$sth = undef;

foreach my $s (@des_query_statements) {
	$s->finish();
}
$des_handle->commit();
$des_sth->finish();
$des_handle->commit();
$des_handle->disconnect();
$dbh->disconnect();

sub populate_descriptions {

	foreach my $s (@des_query_statements) {
		$s->execute();

		while ( my ( $id, $gene, $des ) = $s->fetchrow_array() ) {
			my $string = "";

			if ($gene) {
				$string .= $gene . ', ' . $des;
			}
			else {
				$string .= $des;
			}
			$des_sth->execute( $id, $string );
		}
	}
	$des_handle->do("create index index1 on id_des (id)");

}
