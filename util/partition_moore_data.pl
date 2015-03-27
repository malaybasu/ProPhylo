#!/usr/bin/perl -w
use strict;
use DBI;
use IO::Zlib;

my $db = shift;
my $file = shift;
my $cutoff = shift;

my %already_done;

my $fh = IO::Zlib->new( $file, "rb" );
my $dbh = DBI->connect( "dbi:SQLite:dbname=$db", "", "",
							{ RaiseError => 1, AutoCommit => 0 } );

$dbh->do(
		"create table all_vs_all(
			query text,
			subject text, 
			e_value numeric, 
			score numeric
			)"
	);			
my $sql = 'insert into all_vs_all(query,subject,e_value, score)
				values (?,?,?,?)';
my $sth = $dbh->prepare($sql);
while (my $line = <$fh>) {
	chomp $line;
	my @f = split (/\t/,$line);
	if (exists $already_done{$f[0]} && $already_done{$f[0]} < $cutoff) {
		$sth->execute($f[0], $f[2], 0,$f[1]);
		$already_done{$f[0]}++;
	}elsif (!exists $already_done{$f[0]}){
		$sth->execute($f[0], $f[2], 0,$f[1]);
		$already_done{$f[0]}++;
	}else {
		
	} 
}		

close($fh);
$sth->finish();
$sth= undef;

$dbh->do('create index index1 on all_vs_all (query)');


$dbh->commit();
$dbh->disconnect();


	