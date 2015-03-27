#!/usr/bin/perl -w
use Test::More qw(no_plan);
use FindBin;
use lib "$FindBin::Bin/../lib";
use strict;
use PhyloProf::Profile;
require_ok( "PhyloProf::Algorithm::ppp");
my $test1 = {'A'=>1, 'B' => 0};
my $test2 = {'A'=> 1, 'C'=> 1};

my $prof1 = PhyloProf::Profile->new(-profile=>$test1);
my $prof2 = PhyloProf::Profile->new(-profile=>$test2);

isa_ok($prof1, "PhyloProf::Profile");
isa_ok ($prof2, "PhyloProf::Profile");
my $alg = PhyloProf::Algorithm::ppp->new ($prof2,$prof1);
#print STDERR ref($prof1),"\n";
#print STDERR $prof2,"\n";
#print ref()