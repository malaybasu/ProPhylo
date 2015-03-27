#!/usr/bin/perl -w
use Test::More qw(no_plan);
use FindBin;
use lib "$FindBin::Bin/../lib";
use SeqToolBox::HMMER::Parser;
use Data::Dumper;
use strict;

require_ok("PhyloProf::HMMERResult");
my $seqtoolbox = SeqToolBox::HMMER::Parser->new("t/TIGR03982.hmm.out", 3);
my @array = $seqtoolbox->get_above_cutoff_h3(0);
#print STDERR join('","', @array);
is_deeply (\@array, ["gi|28900300|ref|NP_799955.1|","gi|149377802|ref|ZP_01895534.1|","gi|152996270|ref|YP_001341105.1|","gi|153838941|ref|ZP_01991608.1|","gi|284039627|ref|YP_003389557.1|","gi|294496591|ref|YP_003543084.1|","gi|121722586|gb|ABM64783.1|","gi|89891270|ref|ZP_01202777.1|","gi|119357973|ref|YP_912617.1|","gi|90411301|ref|ZP_01219313.1|"]);
my $hmmer = PhyloProf::HMMERResult->new( -data     => \@array,
									 -value    => "score",
									 -sorted => 1,
		);
#print STDERR Dumper($hmmer->get_profile);

#print STDERR join("\n",@array);

#my %data = ("id1" => 1e10, "id2"=> 1e20, "id3" => 2e15);
##print STDERR @data{("id1", "id2")}, "\n";
#my $blast = PhyloProf::BlastResult->new(-data=> \%data, -value=>"e-value");
##print STDERR @{$blast->{_ids}}, "\n";
#is_deeply($blast->{_ids}, ["id1","id3","id2"]);
#my $blast1 = PhyloProf::BlastResult->new(-data=> \%data, -value=>"score");
#is_deeply($blast1->{_ids}, ["id2","id3","id1"]);
#is_deeply ([$blast->get_ids],["id1","id3","id2"]);
#
#is_deeply ([$blast1->get_ids],["id2","id3","id1"]);
#
#%data = ("29345489" => "1e20");
#my %taxon_class = (29345489 => 226186);
#$blast1 = PhyloProf::BlastResult->new( -data => \%data, -value => "e-value", -taxonomy=>\%taxon_class);
#
#my $profile = $blast1->get_profile();
#isa_ok ($profile, "PhyloProf::Profile");
#my $result = $profile->get_hash();
#my %expected = (226186 => 1);
#is ($profile->is_present(226186), 1);
#foreach my $key (keys %{$result}) {
#	print STDERR $key, "\t", $result->{$key};
#}
#is_deeply (\%expected, $result);