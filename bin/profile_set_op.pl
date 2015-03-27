#!/usr/bin/perl -w
# $Id: profile_set_op.pl 736 2014-07-28 18:01:56Z malay $

##---------------------------------------------------------------------------##
##  File: profile_set_op.pl
##       
##  Author:
##        Malay <malay@bioinformatics.org>
##
##  Description:
##     
#******************************************************************************
#* Copyright (C) 2009 Malay K Basu <malay@bioinformatics.org> 
#* This work is distributed under the license of Perl iteself.
###############################################################################

=head1 NAME

profile_set_op.pl - Performs set operations of profile files.

=head1 SYNOPSIS

profile_set_op.pl -p1 "profile_file1" -p2 "profile_file2" -o "operator"


=head1 DESCRIPTION

This script is for some operations of profile file


=head1 ARGUMENTS 

=over 4

=item B<--help|-h>

Print this page

=item B<--profile1|-p1 profile_file1>

The first profile file.

=item B<--profile2|-p2 profile_file2>

The second profile file.

=item B<--operator| -o string>

This is the operation to be performed on the profile. These are

	and : print a list of taxid where this taxid is 1 in both the profile files
	or 	: print a list of taxid where the taxid is 1 in any of the profile. The taxid must be present in both the files.
	sub	: print a list of taxid where is is present only in the first profile, regardless of the value
	filter: print the taxon ids and the values of the first profile only when it is present in the second profile regardless of their values. 

=item B<--all> 

If given this flag for "and" or "or" operators the final list will include all the taxids in both the profiles with the resultset of the operations. Remember that all the resultset taxids will be set to 1 and these additional taxids will be set to 0, regardless of their original value in the files.

=back


=head1 SEE ALSO

=head1 COPYRIGHT

Copyright (c) 2009 Malay K Basu <malay@bioinformatics.org>

=head1 AUTHORS

Malay K Basu <malay@bioinformatics.org>

=cut



##---------------------------------------------------------------------------##
## Module dependencies
##---------------------------------------------------------------------------##

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
#use SeqToolBox;
#use SeqToolBox::Taxonomy;
use Carp;

my $help;
my $profile1;
my $profile2;
my $op;
my $all;

GetOptions( 'help|h'        => \$help,
			'profile1|p1=s' => \$profile1,
			'profile2|p2=s'      => \$profile2,
			'operator|o=s' => \$op,
			'all|a' => \$all,
) or pod2usage( -verbose => 1 );

if ( $help || !$profile1 || !$profile2 || !$op ) {
	pod2usage( -verbose => 2 );
}

unless (check_file ($profile1) || check_file ($profile2)) {
	die "Error: Input files not present: $!.\n";
}

unless ($op =~ /and/i || $op =~ /or/i || $op =~ /^add/i || $op =~ /^sub/i || $op =~ /^filter/i) {
	croak "Error: Illegal operator: $op\n";
}

my %profile1;
my %profile2;

read_profile ($profile1, \%profile1);
read_profile ($profile2, \%profile2);

my $result;

if ($op =~/and/i) {
	$result = profile_and (\%profile1, \%profile2);
}elsif ($op =~/or/i) {
	$result = profile_or (\%profile1, \%profile2);
	
}elsif ($op =~/^sub/i) {
	$result = profile_sub (\%profile1, \%profile2);
}elsif ($op =~ /^filter/i) {
	$result = profile_filter(\%profile1, \%profile2);
}else {
	croak "Error: Illegal operator: $op\n";
}

print_profile ($result);

sub profile_and {
	
	my $p1 = shift;
	my $p2 = shift;
	
	my %result;
	foreach my $k (keys %{$p1}) {
		if ($p1->{$k} == 1 && (exists $p2->{$k} && $p2->{$k} == 1)) {
			$result{$k} = 1;
			next;
		}
		if ($all) {
			$result{$k} = 0;
			next;
		}
	}
	if ($all) {
		foreach my $k (keys %{$p2}) {
			unless (exists $result{$k}) {
				$result{$k} = 0;
			}
		}
	}
	return \%result;
}


sub profile_or {
	my $p1 = shift;
	my $p2 = shift;
	my %result;
	foreach my $k (keys %{$p1}) {
		if ($p1->{$k} == 1 || (exists $p2->{$k} && $p2->{$k} == 1)) {
			$result{$k} = 1;
			next;
		}
		if ($all) {
			$result{$k} = 0;
			next;
		}
	}
	if ($all) {
		foreach my $k (keys %{$p2}) {
			unless (exists $result{$k}) {
				$result{$k} = 0;
			}
		}
	}
	return \%result;
}

sub profile_sub{
	my $p1 = shift;
	my $p2 = shift;
	my %result;
	foreach my $k (keys %{$p1}) {
		#print $k ;
		if ($p1->{$k} == 1 && (exists $p2->{$k} && $p2->{$k} == 0)) {
			$result{$k} = 1;
			next;
		}
		if ($all) {
			$result{$k} = 0;
			next;
		}
#		if ($all) {
#			$result{$k} = 0;
#			next;
#		}
	}
	if ($all) {
		foreach my $k (keys %{$p2}) {
			unless (exists $result{$k}) {
				$result{$k} = 0;
			}
		}
	}
	return \%result;
}


sub profile_filter {
	my $p1 = shift;
	my $p2 = shift;
	my %result;
	foreach my $k (keys %{$p2}) {
		if (exists $p1->{$k}) {
			$result{$k} = $p1->{$k};
			
		}
	}
	return \%result;
}


sub print_profile {
	my $prof = shift;
	foreach my $k (keys %{$prof}) {
		print $k, "\t", $prof->{$k}, "\n";
	}
}


sub check_file {
	my $file = shift;
	if (-s $file) {
		return 1;
	}
	else {
		return;
	}
}


sub read_profile {
	my $profile_file = shift;
	my $p      = shift;

	open( my $p_in, $profile_file ) || die "Can\'t open $profile_file\n";
	while ( my $line = <$p_in> ) {
		chomp $line;
		my ( $taxid, $value ) = split( /\t/, $line );

		unless ( $taxid || $value ) {
			next;
		}
		unless ($value == 1 || $value == 0) {
			next;
		}
		if ( exists $p->{$taxid} ) {
			die "Duplicate taxon id $taxid in $profile_file\n";
		}
		$p->{$taxid} = $value;
	}
	close($p_in) || die "Can\'t close $profile_file\n";
}
