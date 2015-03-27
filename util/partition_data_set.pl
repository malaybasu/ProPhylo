#!/usr/bin/perl -w
use DBI;
use Carp;

use strict;
my $dbname          = shift;
my $gene_genome_map = 'ppp_gene_genome.sqlite';

my $dbh = DBI->connect( "dbi:SQLite:dbname=$dbname", "", "",
						{ RaiseError => 1, AutoCommit => 1 } );
my $dbh1 = DBI->connect( "dbi:SQLite:dbname=$gene_genome_map",
						 "", "", { RaiseError => 1, AutoCommit => 1 } );

my $sql            = 'select distinct(query_db) from all_vs_all';
my $sql1           = 'select * from all_vs_all where query_db = ?';
my $create_map_sql = 'create table gene_genome_map (id text, query_db text)';
$dbh1->do($create_map_sql);
my $insert_gene_genome
  = 'insert into gene_genome_map (id, query_db) values(?,?)';

my $sth  = $dbh->prepare($sql);
my $sth1 = $dbh->prepare($sql1);
my $sth2 = $dbh1->prepare($insert_gene_genome);

$sth->execute();
while ( my @row = $sth->fetchrow_array() ) {
	my $db           = $row[0];
	my $db_part_name = 'ppp_' . $db . '.sqlite';
	my $dbh2         = DBI->connect( "dbi:SQLite:dbname=$db_part_name",
							 "", "", { RaiseError => 1, AutoCommit => 1 } );
	$dbh2->do(
		"create table all_vs_all_part (
			query text,
			subject_db text, 
			subject text, 
			e_value numeric, 
			score numeric
			)"
	);
	my $sql2 = 'insert into all_vs_all_part (query,subject_db, subject,e_value, score)
				values (?,?,?,?,?)';
	my $sth3 = $dbh2->prepare($sql2);			
	$sth1->execute($db);
	while ( my ( $query_db, $query, $subject_db, $subject, $e_value, $score )
			= $sth1->fetchrow_array() )
	{
		if ($query eq $subject) {next;}
		if ($query_db ne $db) {croak "Something wrong expected $db, got $query_db\n";}
		$sth2->execute($query, $query_db);
		$sth3->execute($query,  $subject_db, $subject,$e_value, $score);

	}
}

$sth->finish();
$sth1->finish();
$sth2->finish();
$sth3->finish();
$dbh->disconnet();
$dbh1->disconnect();
$dbh2->
