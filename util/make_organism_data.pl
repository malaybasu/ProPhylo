#!/usr/bin/perl;
use warnings;
use strict;
use DBI;

my $username = shift;
my $password = shift;

my $dbh = DBI->connect("dbi:Sybase:dbname=common", 
						$username, 
						$password, 
						{RaiseError =>1, AutoCommit => 0});
$dbh->do ('use omnium');						
my $sth = $dbh->prepare('select organism_name, original_db from db_data');

my $dbh1 = DBI->connect ("dbi:SQLite:dbname=cmr_organism2genome.sqlite","","",
						{RaiseError => 1, AutoCommit=>0});
$dbh1->do("create table organism2genome (org text, genome text)");
my $sth1 = $dbh1->prepare('insert into organism2genome (org, genome) values (?,?)');

$sth->execute();

while (my ($o, $g) = $sth->fetchrow_array()) {
	$sth1->execute($o, $g);
}

$dbh1->commit();
$sth->finish();
$sth = undef;
$sth1->finish();
$sth1 = undef;
$dbh->disconnect();
$dbh1->disconnect();