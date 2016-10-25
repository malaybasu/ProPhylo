#!/usr/bin/perl -w
use strict;
use DBI;
use File::Spec;
use SeqToolBox::SeqDB;
use File::Path qw (make_path);

my $fasta = shift;
my $db_dir = shift;
my $dbname = File::Spec->catfile("$db_dir", "desc", "gi_desc.sqlite3" );

if (-s $dbname) {
	die "File $dbname already exists. Please delete it and retry";
}

make_path(File::Spec->catdir("$db_dir","desc"));

my %done;

my $dbh = DBI->connect( "dbi:SQLite:dbname=$dbname", "", "",
							{ RaiseError => 1, AutoCommit => 0 } );
							$dbh->do('create table gi_desc (gi, desc)');
#my $sth = $dbh->prepare('select tax_id from gi_taxid_prot where gi = ?');
my $sth1 = $dbh->prepare('insert into gi_desc values(?,?)');

my $seqdb = SeqToolBox::SeqDB->new (-file => $fasta);

while (my $seq = $seqdb->next_seq()) {
	my $gi = $seq->get_gi() ? $seq->get_gi() :$seq->get_id();
#	my $desc = $seq->get_desc();
  die "$gi not found\n" unless ($gi);

	if (exists $done{$gi}) {
		next;
	}
#	$sth->execute($gi);
#	my $taxon = 0;
#	if (my @array= $sth->fetchrow_array()) {
#		$taxon = 1;
#	}
#
#	unless ($taxon) {
#		print STDERR "Taxon not found for $gi... trying...";
		my $taxon = "";
		my $desc = $seq->get_desc();
		if ($desc =~ /product=\"(.*)\"\s+/) {
			$taxon = $1;
			print $gi,"\t", $taxon,"\n";
		}else {
			$taxon = $desc;
		}
#	}

#	unless ($taxon) {
#		die "Could not determine taxon for $gi\n";
#	}
	$sth1->execute($gi, $taxon);
	$done{$gi} = 1;
}

#$sth->finish();
$sth1->finish();

$dbh->commit();
$dbh->do('create index index1 on gi_desc(gi)');
$dbh->commit();
$dbh->disconnect();
