# Copyright (c) 2002 the World Wide Web Consortium :
#       Keio University,
#       Institut National de Recherche en Informatique et Automatique,
#       Massachusetts Institute of Technology.
# written by Olivier Thereaux <ot@w3.org> for W3C
#
# $Id: HTMLValidator.pm,v 1.1 2003/05/07 02:26:07 ot Exp $

package W3C::LogValidator::HTMLValidator;
use strict;


require Exporter;
our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.2';


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
	$self->{RESULT}	= undef;
	# internal stuff
	$self->{VALID} = undef;
	$self->{VALID_ERR_NUM} = undef;
	$self->{VALID_SUCCESS} = undef;
	$self->{VALID_HEAD} = undef;
	# configuration for this module
	if (@_) {%config =  %{(shift)};}
	$config{ValidatorMethod} = "HEAD" ;
	$config{ValidatorHost} = "validator.w3.org" if (! exists $config{ValidatorHost});
	$config{ValidatorPort} = "80" if (!exists $config{ValidatorPort});
	$config{ValidatorString} = "/check\?uri=" if (!exists $config{ValidatorString});
	$config{ValidatorPostString} = "\;output=xml" if (!exists $config{ValidatorPostString});
	$self->{AUTH_EXT} = ".html .xhtml .phtml .htm /";
	if (exists $config{verbose}) {$verbose = $config{verbose}}
        bless($self, $class);
        return $self;
}

sub uris
{
	#unused
}


sub valid
{
	my $self = shift;
	if (@_) { $self->{VALID} = shift }
		return $self->{VALID};
}

sub valid_err_num
{
	my $self = shift;
	if (@_) { $self->{VALID_ERR_NUM} = shift }
		return $self->{VALID_ERR_NUM};
}

sub valid_success
{
	my $self = shift;
	if (@_) { $self->{VALID_SUCCESS} = shift }
		return $self->{VALID_SUCCESS};
}

sub valid_head
{
        my $self = shift;
        if (@_) { $self->{VALID_HEAD} = shift }
                return $self->{VALID_HEAD};
}


sub auth_ext
{
	my $self=shift;
	if (@_) { $self->{AUTH_EXT} = shift}
	return $self->{AUTH_EXT};
}

sub new_doc{
	my $self=shift;
        $self->{VALID} = undef;
        $self->{VALID_ERR_NUM} = undef;
        $self->{VALID_SUCCESS} = undef;
        $self->{VALID_HEAD} = undef;
}
#########################################
# Actual subroutine to check the list of uris #
#########################################

sub process_list
{
	print "Now using the HTML Validator module... " if $verbose;
	print "\n" if ($verbose > 1);
	
	# Opening the file with the hits and URIs data
	use DB_File; 
	my $tmp_file = $config{tmpfile};
	my %hits;
	tie (%hits, 'DB_File', "$tmp_file", O_RDONLY) || 
		die ("Cannot create or open $tmp_file");
	my @uris = sort { $hits{$b} <=> $hits{$a} } keys %hits;
	
	print "\n (This may take a long time if you have many files to validate)\n" if ($verbose eq 1);
	print "\n" if ($verbose > 2); # trying to breathe in the debug volume...
	use LWP::UserAgent;
	use URI::Escape;
	my $self = shift;
	my $max_invalid = undef;
	if (exists $config{MaxInvalid}) {$max_invalid = $config{MaxInvalid}}
	else {$max_invalid = 0}
	my $name = ""; 
	if (exists $config{ServerName}) {$name = $config{ServerName}}
	my @trimmed_uris;
	foreach my $uri (@uris)
	{
		my @authorized_extensions = split(" ", $self->auth_ext);
		foreach my $ext (@authorized_extensions)
		{
			if ($uri=~ /$ext$/ )
			{ push @trimmed_uris,$uri }
		}
	}
	@uris = @trimmed_uris;
	my @result;
	my @result_head;
	my $intro="Here are the <census> most popular invalid document(s) that I could find in the 
logs for $name.";
	my $outro;
	push @result_head, "Hits";
	push @result_head, "Address";
	push @result_head, "Error Number";
	my $invalid_census = 0; # number of invalid docs
	my $last_invalid_position = 0; # latest position at which we found an invalid doc
	my $total_census = 0; # number of documents checked
	my $ua = new LWP::UserAgent;
#	$ua->timeout([30]); # instead of 180. 3 minutes timeout is too long.
	my $uri = undef;
	while ( (@uris) and  (($invalid_census < $max_invalid) or (!$max_invalid)) )
	# if $max_invalid is 0, process everything
	{
		$uri = shift (@uris);
		$self->new_doc();
		my $uri_orig = $uri;
		$total_census++;
		print "	processing $uri..." if ($verbose > 1);
		# escaping URI
		$uri = uri_escape($uri);
		# creating the HTTP query string with all parameters
		my $string=join ("", "http://",$config{ValidatorHost},":",$config{ValidatorPort},
		$config{ValidatorString},$uri,$config{ValidatorPostString});
		my $method = $config{ValidatorMethod};
		my $request = new HTTP::Request("$method", "$string");
		my $response = new HTTP::Response;
		$response = $ua->simple_request($request);
		if ($response->is_success) # not an error, we could contact the server
		{
			# set both valid and error number according to response
			$self->valid($response->header('X-W3C-Validator-Status'));
			$self->valid_err_num($response->header('X-W3C-Validator-Errors'));
			# we know the validator has been able to (in)validate if $self->valid is not NULL
			if ( ($self->valid) and ($self->valid_err_num) ) # invalid doc
#			if (1) # debug
			{
				my @result_tmp;
				push @result_tmp, $hits{$uri_orig};
				push @result_tmp, $uri_orig;
				push @result_tmp, $self->valid_err_num;
				push @result, [@result_tmp];
				$invalid_census++;
				$last_invalid_position = $total_census;
			}
			printf (" %s!", $self->valid) if ( ($verbose > 1) and (defined ($self->valid)));
			print " Could not validate!" if (($verbose > 1) and(!defined ($self->valid)));

			if (($verbose > 1) and ($self->valid_err_num)) # verbose or debug
				{printf ", %s errors!",$self->valid_err_num}
		}
		else { print " Could not validate!" if ($verbose > 1) }
		print "\n" if ($verbose > 1);

		$self->valid_head($response->as_string); # for debug
		if ($verbose > 2) {printf "%s :\n%s", $string, $self->valid_head;} # debug
		sleep(1); # do not kill validator.w3.org

	}
	print "Done!\n" if $verbose;
	print "invalid_census $invalid_census \n" if ($verbose > 2 );
	if ($invalid_census) # we found invalid docs
	{
		if ($invalid_census eq 1)  # let's repect grammar here
		{
			$intro=~ s/are/is/;
			$intro=~ s/<census> //;
			$intro=~ s/document\(s\)/document/;
		}
		$intro =~s/<census>/$invalid_census/;
		my $ratio = 10000*$invalid_census/$total_census;
		$ratio = int($ratio)/100;
		if ($last_invalid_position eq $total_census )
		# usual case
		{
			$outro="Conclusion :
I had to check $last_invalid_position document(s) in order to find $invalid_census invalid HTML documents.
This means that about $ratio\% of your most popular documents was invalid.";
		}
		else
		# we didn't find as many invalid docs as requested
		{

			$outro="Conclusion :
You asked for $max_invalid invalid HTML document but I could only find $invalid_census 
by processing (all the) $total_census document(s) in your logs. 
This means that about $ratio\% of your most popular documents was invalid.";
		}
	}
	elsif (!$total_census)
	{
		$intro="There was nothing to validate in this log.";
		$outro="";
	}
	else # everything was actually valid!
	{
		$intro=~s/<census> //;
		$outro="I couldn't find any invalid document in this log. Congratulations!";
	}
	untie %hits;
	my %returnhash;
        $returnhash{"name"}="HTMLValidator";
        $returnhash{"intro"}=$intro;
        $returnhash{"outro"}=$outro;
        @{$returnhash{"thead"}}=@result_head;
        @{$returnhash{"trows"}}=@result;
        return %returnhash;         
}

package W3C::LogValidator::HTMLValidator;

1;

__END__

=head1 NAME

W3C::LogValidator::HTMLValidator - check HTML validity vith validator.w3.org

=head1 SYNOPSIS

  use  W3C::LogValidator::HTMLValidator;
  my $validator = new W3C::LogValidator::HTMLValidator;
  my $max_invalid = 12;
	# how many log entries are parsed and returned before we stop
	# 0 -> processes everything
  $validator->uris('http://www.w3.org/', 'http://my.web.server/my/web/page.html');
  my $result_string= $validator->process_list($max_invalid);

=head1 DESCRIPTION

This module is part of the W3C::LogValidator suite, and checks HTML validity
of a given document via the W3C HTML validator service.

=head1 AUTHOR

Olivier Thereaux <ot@w3.org>

=head1 SEE ALSO

W3C::LogValidator, perl(1).
Up-to-date complete info at http://www.w3.org/QA/Tools/LogValidator/

=cut
