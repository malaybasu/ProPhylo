#!/usr/bin/perl -w
use strict;
use DBI;
use SeqToolBox::SeqDB;
my $fasta = shift;
my $dbname = shift;

my $dbh = DBI->connect( "dbi:SQLite:dbname=$dbname", "", "",
							{ RaiseError => 1, AutoCommit => 0 } );
my $sth = $dbh->prepare('select tax_id from gi_taxid_prot where gi = ?');
my $sth1 = $dbh->prepare('insert into gi_taxid_prot values(?,?)');

my $seqdb = SeqToolBox::SeqDB->new (-file => $fasta);

while (my $seq = $seqdb->next_seq()) {
	my $gi = $seq->get_gi();
#	my $desc = $seq->get_desc();
	die "$gi not found\n" unless ($gi);
	$sth->execute($gi);
	my $taxon = 0;
	if (my @array= $sth->fetchrow_array()) {
		$taxon = 1;
	}
	
	unless ($taxon) {
		print STDERR "Taxon not found for $gi... trying...";
		my $desc = $seq->get_desc();
		if ($desc =~ /taxonId=(\d+)/) {
			$taxon = $1;
			print STDERR "found $taxon\n";
			$sth1->execute($gi, $taxon);
		}
	}
	
	unless ($taxon) {
		die "Could not determine taxon for $gi\n";
	}
	
}

$sth->finish();
$sth1->finish();

$dbh->commit();
$dbh->disconnect();
