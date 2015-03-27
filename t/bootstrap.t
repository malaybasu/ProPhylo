#!/usr/bin/perl -w
use Test::More qw(no_plan);
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
BEGIN {
use PhyloProf::Bootstrap;
PhyloProf::Bootstrap->load();
}
require_ok ("PhyloProf::Bootstrap");
require_ok ("Term::ProgressBar");