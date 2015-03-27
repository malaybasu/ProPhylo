#!/usr/bin/perl -w
use strict;
use DBI;

my $username = shift;
my $password = shift;

my $dbh =
  DBI->connect( "dbi:Sybase:dbname=common", $username, $password,
				{ RaiseError => 1 } )
  || die "Can't connect to CMR database\n";



$dbh->do("use omnium");
my $sth = $dbh->prepare("select asm_feature.locus, db_data.original_db 
from asm_feature, db_data  
where (asm_feature.db_data_id = db_data.id) and (asm_feature.feat_type in ('NTORF','ORF'))" 
							
						);
						
my $all_db_handle = DBI->connect(
								  "dbi:SQLite:dbname=id_file_map.sqlite",
								  "", "",
								  {
									 RaiseError => 1,
									 AutoCommit => 0
								  }
);

$all_db_handle->do("drop table if exists id_file_map");
$all_db_handle->do("create table id_file_map (id text, genome text)");
my $all_db_statement = $all_db_handle->prepare(
						 "insert into id_file_map (id, genome) values (?,?)");

$sth->execute;

while (my ($locus, $db) = $sth->fetchrow_array()) {
	$all_db_statement->execute($locus, $db);
}

$all_db_handle->do("create index index1 on id_file_map (id)");
$all_db_statement->finish();
$all_db_handle->commit();
$all_db_statement = undef;
$all_db_handle->disconnect();


$sth->finish();
$sth = undef;
$dbh->disconnect;

