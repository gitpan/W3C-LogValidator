# Copyright (c) YYYY the World Wide Web Consortium :
#       Keio University,
#       European Research Consortium for Informatics and Mathematics 
#       Massachusetts Institute of Technology.
# written by Firstname Lastname <your@email.address> for W3C
#
# $Id: NewModule.pm,v 1.7 2004/03/28 19:31:42 ot Exp $

package W3C::LogValidator::Changeme;
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
	# internal stuff here
	# $self->{FOO} = undef;

	# don't change this
        if (@_) {%config =  %{(shift)};}
	if (exists $config{verbose}) {$verbose = $config{verbose}}
	bless($self, $class);
        return $self;
}


# internal routines
#sub foobar
#{
#	my $self = shift;
#	...
#}


#########################################
# Actual subroutine to check the list of uris #
#########################################


sub process_list
{
	my $self = shift;
	my $max_invalid = undef;
	if (exists $config{MaxInvalid}) {$max_invalid = $config{MaxInvalid}
	print "Now Using the CHANGEME module :\n" if $verbose;
	use DB_File;                                                                  
        my $tmp_file = $config{tmpfile};
	my %hits;                                                                     
	tie (%hits, 'DB_File', "$tmp_file", O_RDONLY) ||                              
	die ("Cannot create or open $tmp_file");                                      
	my @uris = sort { $hits{$b} <=> $hits{$a} } keys %hits;


	# do what pleases you!
	print "Done!\n" if $verbose;



	untie %hits;                                                                  
	
	# Here is what the module will return. The hash will be sent to 
	# the output module

	my %returnhash;
	# the name of the module
	$returnhash{"name"}="CHANGEME";                                                  
	#intro
	$returnhash{"intro"}="An intro string for the module's results";
	#Headers for the result table
	@{$returnhash{"thead"}}=["Header1", "Header2", "..."] ;
	# data for the results table
	@{$returnhash{"trows"}}=
	[
	 ["data1", "data2", "..."]
	 ["etc", "etc", "etc"]
	 ["etc", "etc", "etc"]
	 ["etc", "etc", "etc"]
	];
	#outro
	$returnhash{"outro"}="An outre string for the module's results. Usually the conclusion";
	return %returnhash;
}

package W3C::LogValidator::CHANGEME;

1;

__END__

=head1 NAME

W3C::LogValidator::NewModule - Sample New processing module for the Log Validator

=head1 SYNOPSIS



=head1 DESCRIPTION

This module is part of the W3C::LogValidator suite, and ....

=head1 AUTHOR

you <your@address>

=head1 SEE ALSO

W3C::LogValidator::LogProcessor, perl(1).
Up-to-date complete info at http://www.w3.org/QA/Tools/LogValidator/

=cut
