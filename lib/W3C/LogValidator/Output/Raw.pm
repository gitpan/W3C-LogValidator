# Copyright (c) 2002 the World Wide Web Consortium :
#       Keio University,
#       Institut National de Recherche en Informatique et Automatique,
#       Massachusetts Institute of Technology.
# written by Olivier Thereaux <ot@w3.org> for W3C
#
# $Id: Raw.pm,v 1.1 2003/05/07 02:53:20 ot Exp $

package W3C::LogValidator::Output::Raw;
use strict;


require Exporter;
our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.1';


###########################
# usual package interface #
###########################
our %config;
our $verbose = 1;

sub new
{
        my $self  = {};
        my $proto = shift;
        my $class = ref($proto) || $proto;
	# configuration for this module
	if (@_) {%config =  %{(shift)};}
	if (exists $config{verbose}) {$verbose = $config{verbose}}
        bless($self, $class);
        return $self;
}

sub output
{
	my $self = shift;
	my %results;
	my $outputstr ="";
	if (@_) {%results = %{(shift)}}
	$outputstr= "
************************************************************************
Results for module ".$results{'name'}."
************************************************************************\n";
	$outputstr= $outputstr.$results{"intro"}."\n\n" if ($results{"intro"});
	my @thead = @{$results{"thead"}};
	while (@thead)
	{
		my $header = shift (@thead);	
		$outputstr= $outputstr."$header   ";
	}
	$outputstr= $outputstr."\n";
	my @trows = @{$results{"trows"}};
	while (@trows)
	{
		my @row=@{shift (@trows)};
		my $tcell;
		while (@row)
		{
			$tcell= shift (@row);	
			chomp $tcell;
			$outputstr= $outputstr."$tcell   ";
		}
		$outputstr= $outputstr."\n";
	}
	$outputstr= $outputstr."\n";
	$outputstr= $outputstr.$results{"outro"}."
************************************************************************\n\n" if ($results{"outro"});
	return $outputstr;	
}
	
sub finish
{
# well for this output it's not too difficult :)
	my $self = shift;
	if (@_) 
	{ 
		my $result_string = shift;
		print $result_string;
	}
}

package W3C::LogValidator::Output::Raw;

1;

__END__

=head1 NAME

W3C::LogValidator::Output::Raw - STDOUT (console) output module for the Log Validator


=head1 DESCRIPTION

This module is part of the W3C::LogValidator suite, and displays the results
of the log processing and validation in command-line mode.

=head1 AUTHOR

Olivier Thereaux <ot@w3.org>

=head1 SEE ALSO

W3C::LogValidator, perl(1).
Up-to-date complete info at http://www.w3.org/QA/Tools/LogValidator/
=cut
