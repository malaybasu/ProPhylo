use FindBin;
use lib "$FindBin::Bin/../lib";
use Test::More qw(skip_all =>"R requirement");
use Data::Dumper;



require_ok("PhyloProf::FlexMix");
my $flex = PhyloProf::FlexMix->new();;
my @values = (0,
6.1e-197,
4.6e-183,
1.2e-168,
2.3e-167,
2.3e-167,
4.3e-102,
3.0e-89,
1.3e-54,
1.8e-54,
6.6e-53,
2.1e-48,
6.0e-42,
9.7e-37,
3.7e-19,
6.8e-19,
7.6e-19,
1.4e-18,
2.8e-18,
4.3e-18,
4.4e-18,
2.9e-17,
7.1e-17,
8.5e-17,
1.3e-16,
2.4e-16,
2.9e-16,
8.6e-16,
1.3e-15,
1.6e-15,
2.4e-15,
3.0e-14,
5.6e-12,);
my $cutoff = $flex->classify (@values);
