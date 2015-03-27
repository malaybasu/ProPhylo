# $Id$
# Perl module for HMMER3::Parser
# Author: Malay <malay@bioinformatics.org>
# Copyright (c) 2010 by Malay. All rights reserved.
# You may distribute this module under the same terms as perl itself

##-------------------------------------------------------------------------##
## POD documentation - main docs before the code
##-------------------------------------------------------------------------##

=head1 NAME

HMMER3::Parser  - DESCRIPTION of Object

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=cut

=head1 CONTACT

Malay <malay@bioinformatics.org>


=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

##-------------------------------------------------------------------------##
## Let the code begin...
##-------------------------------------------------------------------------##

package SeqToolBox::HMMER::Parser;
use vars qw(@ISA);
use Bio::SearchIO;
use strict;
use Carp;

##-------------------------------------------------------------------------##
## Constructors
##-------------------------------------------------------------------------##

=head1 CONSTRUCTOR

=head2 new()

=cut

sub new {
	my $class = shift;
	my $self  = {};
	bless $self, ref($class) || $class;
	$self->_init(@_);
	return $self;
}

# _init is where the heavy stuff will happen when new is called

sub _init {
	my ( $self, @args ) = @_;

	#	my $make = $self->SUPER::_initialize;
	$self->{file}    = $args[0];
	$self->{version} = $args[1];

	if ( $args[1] == 2 ) {
		$self->parse_hmmsearch2( $self->{file} );
		$self->parse_hmm2domain( $self->{file} );

	} else {
		$self->parse_hmmsearch3( $self->{file} );
	}

	#	print STDERR @{$self->{result}}, "\n";
	#	return $make;
}

##-------------------------------------------------------------------------##
## M E T H O D S
##-------------------------------------------------------------------------##

=head1 PUBLIC METHODS

=cut

sub parse_hmm2domain {
	my ( $self, $file ) = @_;
	open( my $infile, $file ) || die "Can't open $file\n";
	my $in_result = 0;

	while ( my $line = <$infile> ) {
		chomp $line;
		next unless $line;

		if (    $in_result
			 && $line =~ /^Alignments\s+of\s+top\-scoring\s+domains\:/ )
		{
			last;
		} elsif ( !$in_result && $line =~ /^Parsed\s+for\s+domains\:/ ) {
			my $dummy = <$infile>;
			$dummy     = <$infile>;
			$in_result = 1;
			next;
		} elsif ( $in_result && !$line && $line eq "" ) {
			next;
		} elsif ($in_result) {
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			my @f  = split( /\s+/, $line );
			my $gi = shift(@f);
			my $d  = pop(@f);

			#			$d = pop(@f);
			my $score = pop(@f);

			if ( exists $self->{hmm2_domain}->{$gi} ) {
				if ( $score > $self->{hmm2_domain}->{$gi} ) {
					$self->{hmm2_domain}->{$gi} = $score;
				} else {

					#				$self->{hmm2_domain}->{$gi} = $score;

				}
			} else {
				$self->{hmm2_domain}->{$gi} = $score;
			}
		}

	}
	close($infile);
}

sub get_h2domain_hash {
	my $self = shift;

	if ( exists $self->{hmm2_domain} ) {

		return $self->{hmm2_domain};
	} else {
		return;
	}
}

sub get_h3domain_hash {
	my $self = shift;

	if ( exists $self->{hmm3_domain} ) {
		return $self->{hmm3_domain};
	} else {
		return;
	}
}

sub parse_hmmsearch2 {
	my ( $self, $file ) = @_;
	my @result;
	my @scores;

	#	print STDERR "Hmm2 called\n";
	open( my $infile, $file ) || die "Can't open $file\n";
	my $in_result = 0;

	#	my $result;

	while ( my $line = <$infile> ) {

		#		print STDERR $line;
		chomp $line;

		if ( $in_result && $line =~ /^Parsed\s+for\s+domains\:/ ) {
			last;
		} elsif ( !$in_result && $line =~ /^Query\s+HMM\:/ ) {

			#			for (my $i = 0; $i < 4  ; $i++) {
			#				my $dummy = <$infile>;
			#			}
			while ( my $dummy = <$infile> ) {

				if ( $dummy =~ /^Sequence/ ) {
					last;
				}

			}
			my $dummy = <$infile>;
			$in_result = 1;

			#			print STDERR "**Inresult\n";
			next;
		} elsif ( $in_result
				  && ( $line =~ /inclusion\sthreshold/ || $line eq "" ) )
		{
			next;
		} elsif ($in_result) {

			#			print "*$line\n";
			#			last;
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			my @f  = split( /\s+/, $line );
			my $gi = shift(@f);
			my $d  = pop(@f);
			$d = pop(@f);
			my $score = pop(@f);

			#			print STDERR "fields: ", join('/',$gi, $score),"\n";
			#			$result->{ $f[8] } = $f[1];
			push @result, $gi;
			push @scores, $score;

			#			print "@f\n";

		} else {

		}

	}

	close($infile);

	#	$self->{h3_data} = $result;

	#	my $in = Bio::SearchIO->new( -format => 'hmmer', -file => $file );
	#
	#	while ( my $result = $in->next_result ) {
	#		while ( my $hit = $result->next_hit ) {
	#
	#			#			print STDERR $hit->name(),      "\n";
	#			#			print STDERR $hit->raw_score(), "\n";
	#			push @result, $hit->name();
	#
	#			#			push @result, $hit->name();
	#			push @scores, $hit->raw_score();
	#		}
	#	}
	#	print STDERR "@result\n";
	$self->{result} = \@result;

	$self->{scores} = \@scores;
}

sub get_h2_data_as_hash {
	my $self = shift;

	#	print STDERR "h2 data hash called\n";
	#	print STDERR @{$self->{result}}, "\n";
	if ( !exists $self->{result} || !exists $self->{scores} ) {
		die "Data not found for h2\n";
	}
	my $result;

	for ( my $i = 0; $i < @{ $self->{result} }; $i++ ) {
		$result->{ $self->{result}[$i] } = $self->{scores}[$i];
	}
	return $result;
}

sub get_h3_data_as_hash {
	my $self = shift;

	unless ( exists $self->{h3_data} ) {
		die "Data not found\n";
	}
	return $self->{h3_data};
}

sub get_above_cutoff_t1_t2 {
	my ( $self, $version, $t1_cutoff, $t2_cutoff ) = @_;
	my @result;
	my $gene_data;
	my $domain_data;

	if ( $version == 2 ) {
		$gene_data   = $self->get_h2_data_as_hash();
		$domain_data = $self->get_h2domain_hash();
	} elsif ( $version == 3 ) {
		$gene_data   = $self->get_h3_data_as_hash();
		$domain_data = $self->get_h3domain_hash();
	}else {
		croak "Illegal version number $version\n";
	}

	foreach my $i ( keys %{$gene_data} ) {
		if (    exists $domain_data->{$i}
		 )
		{

			if (    $gene_data->{$i} >= $t1_cutoff
				 && $domain_data->{$i} >= $t2_cutoff )
			{
				push @result, $i;
			}
		}
	}
	return @result;

}

sub get_above_cutoff {
	my ( $self, $cutoff ) = @_;

	unless ( exists $self->{result} ) {
		croak "Could not parse the result\n";

	}
	my @result;

	for ( my $i = 0; $i < @{ $self->{scores} }; $i++ ) {
		if ( $self->{scores}->[$i] >= $cutoff ) {
			push @result, $self->{result}->[$i];
		}
	}
	return @result;
}

sub get_above_cutoff_h3 {
	my ( $self, $cutoff ) = @_;
	my @result;

	foreach my $k ( sort { $self->{h3_data}->{$b} <=> $self->{h3_data}->{$a} }
					keys %{ $self->{h3_data} } )
	{

		if ( $self->{h3_data}->{$k} <= $cutoff ) {
			last;
		} else {
			push @result, $k;
		}
	}
	return @result;

}

sub get_above_cutoff_domain_h3 {
	my ( $self, $cutoff ) = @_;
	my @result;

	foreach my $k ( sort { $self->{hmm3_domain}->{$b} <=> $self->{hmm3_domain}->{$a} }
					keys %{ $self->{hmm3_domain} } )
	{

		if ( $self->{hmm3_domain}->{$k} <= $cutoff ) {
			last;
		} else {
			push @result, $k;
		}
	}
	return @result;

}

sub parse_hmmsearch3 {
	my ( $self, $file ) = @_;
	open( my $infile, $file ) || die "Can't open $file\n";
	my $in_result = 0;
	my $result;
	my $domain_result;
	my $desc;

	while ( my $line = <$infile> ) {
		chomp $line;
		#print STDERR $line , "\n";
		if ( $in_result && ($line =~ /^Domain\sand\salignment/ || $line =~ /^Domain\sannotation/  )) {
			last;
		} elsif ( !$in_result && $line =~ /^Query\:/ ) {

			#			for (my $i = 0; $i < 4  ; $i++) {
			#				my $dummy = <$infile>;
			#			}
			while ( my $dummy = <$infile> ) {

				if ( $dummy =~ /^\s+E\-value/ ) {
					last;
				}

			}
			my $dummy = <$infile>;
			$in_result = 1;
			next;
		} elsif ( $in_result
				  && ( $line =~ /inclusion\sthreshold/ || $line eq "" ) )
		{
			next;
		} elsif ($in_result) {

#									print STDERR "*$line\n";
			#			last;
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			my @f = split( /\s+/, $line );
			$result->{ $f[8] } = $f[1];

			#			print STDERR $f[8], "\n";
			$domain_result->{ $f[8] } = $f[4];
			
			my $desc_string = "";
			for (my $i = 9; $i <@f;$i++) {
				if ($f[$i]) {
					$desc_string .= " ". $f[$i];
				}
			}
			
			$desc->{$f[8]} = $desc_string;
			#			print "@f\n";

		} else {

		}

	}

	close($infile);
	$self->{h3_data}     = $result;
	$self->{hmm3_domain} = $domain_result;
	$self->{desc} = $desc;
}

sub get_desc {
	my ($self, $gi) = @_;
	if (exists $self->{desc}->{$gi}){
		return $self->{desc}->{$gi};
	}else {
		return;
	}
	
}


sub find_cutoff_in_h3 {
	my ( $self, $result ) = @_;

	unless ( exists $self->{h3_data} ) {
		croak "Can't find H3 data\n";
	}
	my %resultset;
	my $count = 0;

	foreach my $h2 ( @{$result} ) {
		if ( exists $self->{h3_data}->{$h2} ) {
			$resultset{$h2} = $self->{h3_data}->{$h2};
			$count++;
		}
	}
	print STDERR "Found $count sequences in H3 results\n";
	my @sorted_data
		= sort { $resultset{$a} <=> $resultset{$b} } keys(%resultset);

	#print STDERR "Found $count sequences\n";
	return $count, $resultset{ $sorted_data[0] };

	#	print $sorted_data[0], "\t", $resultset{$sorted_data[0]},"\n";

}

sub find_weighted_score {
	my ( $self, $cutoff, $h2_data ) = @_;

#hmmer2 can have -ve scale which will screw up the calculation so we will first rescale the data in the the positive;

	#first get the lowest value
	my $lowest_value;

	foreach my $k ( sort { $h2_data->{$a} <=> $h2_data->{$b} }
					keys %{$h2_data} )
	{
		$lowest_value = $h2_data->{$k};
		last;
	}

	#lowest_value is -ve then push everything up by this
	my $rescale_factor = 0;

	if ( $lowest_value < 0 ) {
		$rescale_factor = -($lowest_value)
			;    # this should be added to every value to make it +ve;
		$cutoff = $cutoff + $rescale_factor;
	}

	#Now cutoff can not be negative;
	if ( !$cutoff || $cutoff == 0 ) {
		return;
	}

	print STDERR "Rescale factor: $rescale_factor\t cutoff: $cutoff\n";
	my $best_score = 0;
	my $positive_count;
	my $best_weight  = 0;
	my $serial_count = 0;
	my $weight       = 0;

	foreach my $k ( sort { $self->{h3_data}->{$b} <=> $self->{h3_data}->{$a} }
					keys %{ $self->{h3_data} } )
	{
		next unless exists $h2_data->{$k};
		my $h2_score = $h2_data->{$k};

		#		my $weight;
		if ( $h2_score >= $cutoff ) {

			#			if ($cutoff < 0) {
			#				$weight = $weight + (($h2_score + $cutoff)/ -($cutoff));
			#			}else {
			$weight = $weight
				+ ( ( ( $h2_score + $rescale_factor ) - $cutoff ) / $cutoff );

			#			}
			$positive_count++;
		} else {

			#			if ($cutoff < 0) {
			#				$weight = $weight - (($cutoff - (-$h2_score))/$cutoff);
			#			}else {
			$weight = $weight
				- ( ( $cutoff - ( $h2_score + $rescale_factor ) ) / $cutoff );

			#			}
		}

		if ( $weight > $best_weight ) {
			$best_weight = $weight;
			$best_score  = $self->{h3_data}->{$k};
		}

		#		$best_weight = $weight;
		print STDERR ++$serial_count, "\t", $self->{h3_data}->{$k}, "\t",
			$best_weight, "\t", $weight, "\t", $best_score, "\n";
	}
	print STDERR "$best_score\t$best_weight\t\n";
	return $positive_count, $best_score;

}

=head1 PRIVATE METHODS

=cut

=head1 SEE ALSO

=head1 COPYRIGHTS

Copyright (c) 2010 by Malay <malay@bioinformatics.org>. All rights reserved.
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

=head1 APPENDIX

=cut

1;
