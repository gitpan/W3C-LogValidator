# Copyright (c) 2004 the World Wide Web Consortium :
#       Keio University,
#       European Research Consortium for Informatics and Mathematics 
#       Massachusetts Institute of Technology.
# written by Matthieu Faure <matthieu@faure.nom.fr> for W3C
# maintained by olivier Thereaux <ot@w3.org> and Matthieu Faure <matthieu@faure.nom.fr>
# SurveyEngine.pm v0.1 2004/05/17

package W3C::LogValidator::SurveyEngine;
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
        if (exists $config{AuthorizedExtensions})
        {
                $self->{AUTH_EXT} =  $config{AuthorizedExtensions};
        }
        else # same as the formats supported by markup Validator
	# TODO add support for CSS too, at least
        {
		$self->{AUTH_EXT} = ".html .xhtml .phtml .htm .shtml .php .svg .xml /";
	}
	$config{ValidatorHost} = "validator.w3.org" if (! exists $config{ValidatorHost});
	$config{ValidatorPort} = "80" if (!exists $config{ValidatorPort});
	$config{ValidatorString} = "/check\?uri=" if (!exists $config{ValidatorString});
	$config{ValidatorVersion} = "0.6.5" if (!exists $config{ValidatorVersion});
	bless($self, $class);
        return $self;
}


sub auth_ext
{
	my $self=shift;
	if (@_) { $self->{AUTH_EXT} = shift}
	return $self->{AUTH_EXT};
}



#########################################
# Actual subroutine to check the list of uris #
#########################################


sub process_list
  {
    my $self = shift;
    my $max_invalid = undef;
    my $max_documents = undef;
    if ( exists $config{MaxInvalid} ) { $max_invalid = $config{MaxInvalid}; }
    else {$max_invalid = 0;}
    if (exists $config{MaxDocuments}) {$max_documents = $config{MaxDocuments}; }
    else {$max_documents = 0;}
    # print "$max_documents max documents" if ($verbose > 2); # debug
    my $name = ""; 
    if (exists $config{ServerName}) {$name = $config{ServerName}}


    print "Now Using the SurveyEngine module...\n" if $verbose;
    use URI::Escape;
    use LWP::UserAgent;
    use DB_File;
    my $tmp_file = $config{tmpfile};
    my %hits;
    tie (%hits, 'DB_File', "$tmp_file", O_RDONLY) ||
      die ("Cannot create or open $tmp_file");
    my @uris = sort { $hits{$b} <=> $hits{$a} } keys %hits;
					
    my @result_head;
    #push @result_head, "Hits";
    push @result_head, "Rank";
    push @result_head, "Hits";
    push @result_head, "URI";
    push @result_head, "Charset";
    push @result_head, "Doctype";
    push @result_head, "Valid (#err)";
	
    my @result;
    my $uri = undef;
    my $ua = new LWP::UserAgent;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    $mon = sprintf ( "%02d", $mon);
    $mday = sprintf ("%02d", $mday);
    my $localDate = "$year-$mon-$mday" ;
    my $census = 0;

    my @trimmed_uris;
    foreach my $uri (@uris)
	{
		my @authorized_extensions = split(" ", $self->auth_ext);
		foreach my $ext (@authorized_extensions)
		{
			if ($uri=~ /$ext$/ )
			{ 
				push @trimmed_uris,$uri;
			#	print "$uri accepted" if ($verbose >2); #debug
			 }
			#else { print "$uri left out" if ($verbose >2);} # debug
			
		}
	}
    @uris = @trimmed_uris;

    while ((@uris) and  (($census < $max_documents) or (!$max_documents)) )
    {
      # a few initializations
      $uri = shift (@uris);
      my $uri_orig = $uri;
      $uri = uri_escape($uri);
      my @result_tmp = ();
      print "	processing #$census $uri_orig...\n" if ($verbose > 1);
     $census = $census+1;
      # filling result table with "fixed" content
      push @result_tmp, $census;
      push @result_tmp, $hits{$uri_orig};
      push @result_tmp, $uri_orig;

      my $validatorUri = join ("", "http://",$config{ValidatorHost},":",$config{ValidatorPort}, $config{ValidatorString},$uri);
	
      my $testStringCharset = undef;
      my $testStringDoctype = undef;
      my $testStringInvalid = undef;
      my $testStringValid = undef;
	  my $testStringErrorNum = undef;

	  if ( $config{ValidatorVersion} eq "0.6.1" ) {
		$testStringCharset = 'I was not able to extract a character encoding labeling from any of';
		$testStringDoctype = '<h2>Fatal Error: No DOCTYPE specified!</h2>';
		$testStringInvalid = '<h2 id="result" class="invalid">This page is <strong>not</strong> Valid';
		$testStringValid = '<h2 id="result" class="valid">This Page Is Valid';
		$testStringErrorNum = '<th>Errors: </th>.*?<td>(\d+)</td>';
      } else {
		# Default ValidatorVersion is 0.6.5 (current version as of may 2004)
		$testStringCharset = 'found are not valid values in the specified Character Encoding';
		$testStringDoctype = '<h3>No DOCTYPE Found!';
		$testStringInvalid = '<h2 class="invalid">This page is <strong>not</strong> Valid';
		$testStringValid = '<h2 id="result" class="valid">This Page Is Valid';
		$testStringErrorNum = '<th>Errors: </th>.*?<td>(\d+)</td>';
      }

      my $request = new HTTP::Request("GET", $validatorUri );
      my $validatorResponse = new HTTP::Response;
      $validatorResponse = $ua->simple_request($request);

      if ( ! $validatorResponse->is_success ) {
		push @result_tmp, "N/A";
		push @result_tmp, "N/A";
		push @result_tmp, "can't connect";
      } else {
		# Actual tests
		if ( $validatorResponse->content =~ $testStringCharset ) {
		  push @result_tmp, "No";
		  push @result_tmp, "N/A";
		  push @result_tmp, "N/A";
		}
		elsif ( $validatorResponse->content =~ $testStringDoctype ) {
		  push @result_tmp, "Yes";
		  push @result_tmp, "No";
		  push @result_tmp, "N/A";
		}
		elsif ( $validatorResponse->content =~ $testStringInvalid ) 
		{
		   push @result_tmp, "Yes";
		   push @result_tmp, "Yes";
		
		   if ( $validatorResponse->content =~ m!$testStringErrorNum!ms ) 
		   {
			print "Invalid... $1 Errors \n" if $verbose;
			push @result_tmp, "No ($1)";
		   } 
		   else 
		   {
			push @result_tmp, "No (?)";
		   }
		}
		elsif ( $validatorResponse->content =~ $testStringValid ) {
		  push @result_tmp, "Yes";
		  push @result_tmp, "Yes";
		  push @result_tmp, "Yes";
		} else {
		  push @result_tmp, "N/A";
		  push @result_tmp, "N/A";
		  push @result_tmp, "Could not validate";
		}
      }
      # store results for this URI in table of results
      push @result, [@result_tmp];
    }
    my $intro_str = "Here are the $census most popular documents surveyed for $name on .";
    print "Done!\n" if $verbose;
    #print "Result: @result \n" if $verbose;
    untie %hits;
	
    # Here is what the module will return. The hash will be sent to 
    # the output module

    my %returnhash;
    # the name of the module
    $returnhash{"name"}="SurveyEngine";
    #intro
    $returnhash{"intro"}=$intro_str;
    #Headers for the result table
    @{$returnhash{"thead"}} = @result_head;
    # data for the results table
    @{$returnhash{"trows"}} = @result;
    #outro
    $returnhash{"outro"}="";
    return %returnhash;
}

package W3C::LogValidator::SurveyEngine;

1;

__END__

=head1 SurveyEngine

W3C::LogValidator::SurveyEngine - Processing module for the Log Validator to run websites validity surveys

=head1 SYNOPSIS

Module to run websites validity surveys

=head1 DESCRIPTION

This module is part of the W3C::LogValidator suite, and ....

=head1 AUTHOR

Matthieu Faure  <matthieu@faure.nom.fr>

=head1 SEE ALSO

W3C::LogValidator::LogProcessor, perl(1).
Up-to-date complete info at http://www.w3.org/QA/Tools/LogValidator/

=cut
