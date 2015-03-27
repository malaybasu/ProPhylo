#!/usr/bin/perl -w
use Test::More qw(no_plan);
use FindBin;
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use strict;

require_ok("PhyloProf::BlastResult");
my %data = ("id1" => 1e10, "id2"=> 1e20, "id3" => 2e15);
#print STDERR @data{("id1", "id2")}, "\n";
my $blast = PhyloProf::BlastResult->new(-data=> \%data, -value=>"e-value");
#print STDERR @{$blast->{_ids}}, "\n";
is_deeply($blast->{_ids}, ["id1","id3","id2"]);
my $blast1 = PhyloProf::BlastResult->new(-data=> \%data, -value=>"score");
is_deeply($blast1->{_ids}, ["id2","id3","id1"]);
is_deeply ([$blast->get_ids],["id1","id3","id2"]);

is_deeply ([$blast1->get_ids],["id2","id3","id1"]);

%data = ("29345489" => "1e20");
my %taxon_class = (29345489 => 226186);
$blast1 = PhyloProf::BlastResult->new( -data => \%data, -value => "e-value", -taxonomy=>\%taxon_class);
#print STDERR Dumper $blast1;
my $profile = $blast1->get_profile();
print STDERR Dumper $profile;
isa_ok ($profile, "PhyloProf::Profile");
my $result = $profile->get_hash();
#print STDERR Dumper($result);
if (ref($result) eq "ARRAY") {
	is_deeply ([226186], $result);
}else {
my %expected = (226186 => 1);

#foreach my $key (keys %{$result}) {
#	print STDERR $key, "\t", $result->{$key};
#}
is_deeply (\%expected, $result);
}
is ($profile->is_present(226186), 1);