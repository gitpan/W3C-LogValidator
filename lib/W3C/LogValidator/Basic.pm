# Copyright (c) 2002 the World Wide Web Consortium :
#       Keio University,
#       Institut National de Recherche en Informatique et Automatique,
#       Massachusetts Institute of Technology.
# written by Olivier Thereaux <ot@w3.org> for W3C
#
# $Id: Basic.pm,v 1.1 2003/05/07 02:26:07 ot Exp $

package W3C::LogValidator::Basic;
use strict;
use warnings;


require Exporter;
our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.1';


###########################
# usual package interface #
###########################
our $verbose = 1;
our %config;

sub new
{
        my $self  = {};
        my $proto = shift;
        my $class = ref($proto) || $proto;
	# mandatory vars for the API
	$self->{URIS}	= undef;
	# don't change this
	if (@_) {%config =  %{(shift)};}
	if (exists $config{verbose}) {$verbose = $config{verbose}}
        bless($self, $class);
        return $self;
}

sub uris { 
# unused
}

#########################################
# Actual subroutine to check the list of uris #
#########################################


sub process_list
{
	my $self = shift;
	my $max_invalid = undef;
	if (exists $config{MaxInvalid}) {$max_invalid = $config{MaxInvalid}}
	else {$max_invalid = 0}
	my $name = "";
	if (exists $config{ServerName}) {$name = $config{ServerName}}

	print "Now Using the Basic module... \n" if $verbose;
	# Opening the file with the hits and URIs data
	use DB_File;
	my $tmp_file = $config{tmpfile};
	my %hits;

	tie (%hits, 'DB_File', "$tmp_file", O_RDONLY) ||
        die ("Cannot create or open $tmp_file");
	my @uris = sort { $hits{$b} <=> $hits{$a} }                                   
                keys %hits;

	my $intro="Here are the <census> most popular documents overall for the server $name.";
	my @result;
	my @result_head;
	push @result_head, "Rank";
	push @result_head, "Hits";
	push @result_head, "Address";
	my $census = 0;
	while ( (@uris) and  (($census < $max_invalid) or (!$max_invalid)) )
	{
		my $uri = shift (@uris);
		chomp ($uri);
		my @result_tmp;
		$census++;
		push @result_tmp, "$census";
		push @result_tmp, "$hits{$uri}";
		push @result_tmp, "$uri";
		push @result, [@result_tmp];
	}
	print "Done!\n" if $verbose;
	if ($census eq 1) # let's repect grammar here
                {
                        $intro=~ s/are/is/;
                        $intro=~ s/<census> //;
                        $intro=~ s/document\(s\)/document/;
                }
	else
	{
		$intro=~ s/<census>/$census/;
	}
	untie %hits;
	my $outro="";
	my %returnhash;
	$returnhash{"name"}="basic";
	$returnhash{"intro"}=$intro;
	$returnhash{"outro"}=$outro;
	@{$returnhash{"thead"}}=@result_head;
	@{$returnhash{"trows"}}=@result;
	return %returnhash;
}

package W3C::LogValidator::Basic;

1;

__END__

=head1 NAME

W3C::LogValidator::Basic

=head1 SYNOPSIS

  use  W3C::LogValidator::Basic;
  my $validator = new W3C::LogValidator::Basic;
  my $max_invalid = 12;
	# how many log entries are parsed and returned before we stop
	# 0 -> processes everything
  my $result_string= $validator->process_list($max_invalid);

=head1 DESCRIPTION

This module is part of the W3C::LogValidator suite, and simply gives back pages
sorted by popularity. This is an example of simple module for LogValidator.

=head1 AUTHOR

Olivier Thereaux <ot@w3.org> for W3C

=head1 SEE ALSO

W3C::LogValidator, perl(1).
Up-to-date complete info at http://www.w3.org/QA/Tools/LogValidator/

=cut
