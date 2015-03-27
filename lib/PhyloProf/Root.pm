package PhyloProf::Root;    
use strict;


sub _rearrange {
	my $self  = shift;
	my $order = shift;
	return @_ unless ( substr( $_[0] || '', 0, 1 ) eq '-' );
	push @_, undef unless $#_ % 2;
	my %param;
	while (@_) {
		( my $key = shift ) =~ tr/a-z\055/A-Z/d;
		$param{$key} = shift;
	}
	map { $_ = uc($_) } @{$order};
	return @param{@$order};
}


1;
