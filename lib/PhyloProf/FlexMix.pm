# $Id: FlexMix.pm 512 2009-11-25 21:28:50Z malay $
# Perl module for PhyloProf::FlexMix
# Author: Malay <malaykbasu@gmail.com>
# Copyright (c) 2009 by Malay. All rights reserved.
# You may distribute this module under the same terms as perl itself

##-------------------------------------------------------------------------##
## POD documentation - main docs before the code
##-------------------------------------------------------------------------##

=head1 NAME

PhyloProf::FlexMix  - DESCRIPTION of Object

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

package PhyloProf::FlexMix;

use vars qw(@ISA);
@ISA       = qw();
@EXPORT_OK = qw();
use strict;
use Carp;
use R;
use RReferences;
use Data::Dumper;

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

	R::initR('--silent');
	R::library("RSPerl");

	#&R::eval("print(search()); T");
	#&R::eval("setPerlHandler(); T");
	#&R::eval("print(getPerlHandler()); T");

	R::library("flexmix");

}

##-------------------------------------------------------------------------##
## METHODS
##-------------------------------------------------------------------------##

=head1 PUBLIC METHODS

=cut

sub classify {
	my ( $self, @results ) = @_;
	my $number = scalar(@results);
	my @sorted_results = sort { $a <=> $b } @results;
	my @x;

	#print STDERR $self->minus_log10(1e-10);
	my @y;
	my @residuals;
	my $count = 0;

	for ( my $i = 0; $i < $number; $i++ ) {

		#	push @x, $i+1;
		my $value = $self->minus_log10( $sorted_results[$i] );

		if ( $value != 0 ) {
			push @y, $value;
			push @x, ++$count;
		}
		else {
			push @residuals, 0;
		}
	}

	#print STDERR "X = @x\n";
	#print STDERR "Y = @y\n";
	#print STDERR "Number of y ", scalar (@y),"\n";
	#	my @some = R::call("rnorm", 10);
	#	print "@some\n";

	my $r_statement
		= 'd<<-data.frame(x=c('
		. join( ",", @x )
		. '),y=c('
		. join( ",", @y ) . '))';

	#	my @df=&R::call('data.frame',\@x,\@y);
	#	print STDERR $r_statement;
	my @df = R::eval($r_statement);

	#R::eval('print(d)');
	#R::eval('print(d$x)');
	#R::eval('print(d$y)');
	#	print STDERR @df, "\n";
	#print STDERR Dumper(\@df);
	my @result = &R::eval('m1<<-flexmix(d$y~d$x,data=d,k=3)');
	R::eval('print(m1)');
	my @return_values = &R::eval('print(clusters(m1))');

	#print STDERR "@return_values\n";
	#print Dumper(\@result),"\n";

	my @clusters;
	my $first  = $return_values[0];
	my $cutoff = $y[0];

	for ( my $i = 0; $i < @y; $i++ ) {
		if ( $return_values[$i] == $first ) {
			$cutoff = $y[$i];
		}
	}

	my $print_statement = 'pdf("cutoff_output.pdf",paper="letter")';
	R::eval($print_statement);

	#$print_statement = 'plot(x=c('.join(",",@x).',y=c('.join(",", @y).'))';
	R::eval('plot(d$x,d$y,xlab="Hit order",ylab="log(e-value)")');
	R::eval( 'abline(h=' . $cutoff . ')' );
	R::eval('dev.off()');
	print "Cutoff $cutoff\n";

	#&R::call("print", @result);
	my $real_cutoff = $sorted_results[0];

	for ( my $i = 0; $i < @sorted_results; $i++ ) {
		my $transformed_value = $self->minus_log10( $sorted_results[$i] );

		#		print STDERR "Transformed $transformed_value\n";
		if ( $self->minus_log10( $sorted_results[$i] ) >= $cutoff ) {

			#			print STDERR "$cutoff $real_cutoff\n";
			$real_cutoff = $results[$i];
		}
	}
	return $real_cutoff;
}

sub minus_log10 {
	my ( $self, $number ) = @_;

	if ( $number < 0 ) {
		croak "Log of negative number doesnot make sense\;";
	}

	if ( $number == 0 ) {
		return 0;
	}
	else {
		my $value = log($number) / log(10);
		return -$value;
	}
}

=head1 PRIVATE METHODS

=cut

sub DESTROY {

}

=head1 SEE ALSO

=head1 COPYRIGHTS

Copyright (c) 2009 by Malay <malaykbasu@gmail.com>. All rights reserved.
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

=head1 APPENDIX

=cut

1;
