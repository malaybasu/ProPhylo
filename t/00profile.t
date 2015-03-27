#!/usr/bin/perl -w
use FindBin;
use lib "$FindBin::Bin/../lib";
use Test::More qw(no_plan);
use Data::Dumper;
use PhyloProf::DB::CMR;

require_ok("PhyloProf::Profile");
#my $p = PPP::Profile->new();
my $profile = PhyloProf::Profile->new(-file=>"$FindBin::Bin/sulf_mod.profile");
isa_ok($profile, "PhyloProf::Profile");
is($profile->{_yes}, 9);
is($profile->{_no}, 425);
is ($profile->get_odds(), 0.021);
my %test = ("A" => 1, "B" => 0);
my $profile1 = PhyloProf::Profile->new(-profile=> \%test);
my $return = $profile1->get_hash();
is ($profile1->get_total, 2);
is_deeply (\%test, $return);
#my $cmr = PhyloProf::DB::CMR->new(-dbdir=> '/export/DB/temp', -website=> 'http://mbasu-lx:8000/omnium/');
#my $profile2 = $cmr->get_profile_by_id("NTL01HC6738");
#print Dumper($profile2);
%test = ("1140" => 1);
$profile2 = PhyloProf::Profile->new(-profile=>\%test,-rank=>"family");
is ($profile2->is_present(1129), 1);
is ($profile2->get_total, 1);
%test = ("1129"=>1);
$return = $profile2->get_hash();
is_deeply( $return,\%test);

$profile2 = PhyloProf::Profile->new(-file=>"t/test.profile",-rank=>"family");
is ($profile2->is_present(1129), 1);
is ($profile2->get_total, 1);
%test = ("1129"=>1);
$return = $profile2->get_hash();
is_deeply( $return,\%test);
