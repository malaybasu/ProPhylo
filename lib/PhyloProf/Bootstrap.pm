package PhyloProf::Bootstrap;
use strict;
use warnings;
use File::Spec;
use FindBin;
use lib "$FindBin::Bin/../cpan";
my @required_modules = ("Term::ProgressBar");

#print STDERR "Bootsrap loaded\n";

sub load {
	my $class = shift;

	foreach my $module (@required_modules) {

		eval "use $module";

		if ($@) {
			$module =~ s/\:\:/-/;
			my $path = File::Spec->catdir( $FindBin::Bin, "..", "cpan", $module,
										   '*.par' );
			my $command = "use PAR '" . $path . "'";

			#		print STDERR $command;
			eval "$command";

			if ($@) {
				die "Could not load $module\n";
			}
		}

	}
}

1;
