#!/usr/bin/perl -w
BEGIN {
	$ENV{JCVI_CMR_DB_DIR} = '/export/DB/omnium_parsed';
}
use Test::More skip_all =>'Inernal';
use FindBin;
use lib "$FindBin::Bin/../lib";

require_ok ("PhyloProf::DB::CMR");
my $cmr = PhyloProf::DB::CMR->new(-dbdir=> '/export/DB/temp', -website=> 'http://mbasu-lx:8000/omnium/');
is($cmr->get_dbdir(),'/export/DB/temp');
#my $cmr1 = PhyloProf::DB::CMR->new (-local=>1, -dbdir=> "/export/DB/omnium_parsed");
#is ($cmr1->get_dbdir(), '/export/DB/omnium_parsed');

my $cmr2 = PhyloProf::DB::CMR->new(-dbdir=>'/export/DB/temp', -website=>'http://mbasu-lx:8000/omnium/');
is($cmr2->get_dbdir(), '/export/DB/temp');
is ($cmr2->get_db_by_id("MSMEG_6946"), "gms");
is (scalar($cmr2->get_ids_by_db ("gms")), 6861);
is (scalar($cmr2->get_hit_list_by_id("MSMEG_6946")), 399);
my @hitlist = $cmr2->get_hit_list_by_id ("MSMEG_6946");
#print STDERR join("\n", @hitlist), "\n";
my $prof = $cmr2->get_profile_by_id ("MSMEG_6946");
isa_ok($prof, "PhyloProf::Profile");
is($prof->get_total(), '399');
is ($cmr2->get_des_by_id("NTL01HC6738"), "3-phosphoadenosine 5-phosphosulfate sulfotransferase (PAPS reductase)/FAD synthetase and related enzyme");
#print STDERR "Yes:", $prof->get_yes(), "\n";

#my $prof = $cmr2->get_profile_by_id("MSMEG_6946");
#isa_ok($prof, "PhyloProf::Profile");
#is($prof->get_total(), 369);
#is(scalar($cmr2->get_ids_by_db(50723)), 6760);