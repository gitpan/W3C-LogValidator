# Copyright (c) YYYY the World Wide Web Consortium :
#       Keio University,
#       European Research Consortium for Informatics and Mathematics 
#       Massachusetts Institute of Technology.
# written by olivier Thereaux <ot@w3.org> for W3C
#
# $Id: CSSValidator.pm,v 1.4 2004/06/09 01:43:11 ot Exp $

package W3C::LogValidator::CSSValidator;
use strict;
use warnings;
use WebService::Validator::CSS::W3C;


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
	# don't change this
        if (@_) {%config =  %{(shift)};}
	if (exists $config{verbose}) {$verbose = $config{verbose}}
	if (exists $config{AuthorizedExtensions})
	{
		$self->{AUTH_EXT} =  $config{AuthorizedExtensions};
	}
	else
	{
		$self->{AUTH_EXT} = ".css";
	}
	bless($self, $class);
        return $self;
}


# internal routines

sub new_doc{
        my $self=shift;
	$self->{VALID} = undef;
        $self->{VALID_ERR_NUM} = undef;
        $self->{VALID_SUCCESS} = undef;
}

sub auth_ext
{
        my $self=shift;
        if (@_) { $self->{AUTH_EXT} = shift}
        return $self->{AUTH_EXT};
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


sub HEAD_check {
## Checking whether a document with no extension is actually a CSS file
## causes a lot of requests, but internal - should be OK?
        my $self = shift;
        my $check_uri;
        use LWP::UserAgent;
        if (@_) { $check_uri = shift }
        my $ua = new LWP::UserAgent;
        my $method = "HEAD";
        my $request = new HTTP::Request("$method", "$check_uri");
        my $response = new HTTP::Response;
        $response = $ua->simple_request($request);
        my $is_css = 0;
        if ($response->is_success) # not an error, we could contact the server
        {
                my $type = $response->header('Content-Type');
                if ($type =~ /text\/css/) 
                {
                        $is_css = 1;
                        print "URI with no extension $check_uri has content-type $type\n" if ($verbose > 2); # debug
                }
        }
        return $is_css;
}

sub trim_uris 
{
	my $self = shift;
        my @authorized_extensions = split(" ", $self->auth_ext);
	my @trimmed_uris;
	my $uri;
        while ($uri = shift)
        {
                my $uri_ext = "";
                my $match = 0;
                if ($uri =~ /(\.[0-9a-zA-Z]+)$/)
                {
                   $uri_ext = $1;
                }
                elsif ($uri =~ /\/$/) { $uri_ext = "/";}
                elsif ( $self->HEAD_check($uri) ) { $match = 1; }
                foreach my $ext (@authorized_extensions)
                {
                    if ($ext eq $uri_ext) { $match = 1; }
                }
                push @trimmed_uris,$uri if ($match);
        }
	return @trimmed_uris;
}

#########################################
# Actual subroutine to check the list of uris #
#########################################


sub process_list
{
	my $self = shift;
	my $max_invalid = undef;
	if (exists $config{MaxInvalid}) {$max_invalid = $config{MaxInvalid}}
        my $max_documents = undef;                                                                      
        if (exists $config{MaxDocuments}) {$max_documents = $config{MaxDocuments}}                      
        else {$max_documents = 0}
	print "Now Using the CSS Validation module...\n" if $verbose;
	use DB_File;                                                                  
        my $tmp_file = $config{tmpfile};
	my %hits;                                                                     
	tie (%hits, 'DB_File', "$tmp_file", O_RDONLY) ||                              
	die ("Cannot create or open $tmp_file");                                      
	my @uris = sort { $hits{$b} <=> $hits{$a} } keys %hits;
	my $name = "";
	if (exists $config{ServerName}) {$name = $config{ServerName}}
       	my @result;
        my @result_head;
        push @result_head, "Rank";
        push @result_head, "Hits";
        push @result_head, "#Error(s)";
        push @result_head, "Address";

        my $intro="Here are the <census> most popular invalid document(s) that I could find in the 
logs for $name.";
        my $outro;

        @uris = $self->trim_uris(@uris);
	my $invalid_census = 0; # number of invalid docs
	my $last_invalid_position = 0; # latest position at which we found an invalid doc
	my $total_census = 0; # number of documents checked

        my $uri = undef;
	# bulk of validation
        while ( (@uris) and  (($invalid_census < $max_invalid) or (!$max_invalid)) and (($total_census < $max_documents) or (!$max_documents)) )
	{
		$uri = shift (@uris);
		my $uri_orig = $uri;
		$self->new_doc();
		$total_census++;
                print "	processing #$total_census $uri... " if ($verbose > 1);
		my $val = WebService::Validator::CSS::W3C->new;
		$val->validate(uri => $uri);
		$self->valid_success($val->success);
		$self->valid($val->is_valid);
		my @errors = $val->errors;
		$self->{VALID_ERR_NUM} = int( @errors );
		
		if (! $self->valid_success)
		{
			print " Could not validate!" if ($verbose > 1);
		}
		else
		{
			if ($self->valid) # success, valid
			{
				print "Valid!" if ($verbose > 1);
			}
			else # success - not valid -> invalid
			{
				printf ("Invalid, %s error(s)!",$self->valid_err_num) if ($verbose > 1);; 
				my @result_tmp;
				push @result_tmp, $total_census;
				push @result_tmp, $hits{$uri_orig};
				push @result_tmp, $self->valid_err_num;
				push @result_tmp, $uri_orig;
				push @result, [@result_tmp];
				$invalid_census++;
				$last_invalid_position = $total_census;
			}
		}
		print "\n" if ($verbose > 1);


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
I had to check $last_invalid_position document(s) in order to find $invalid_census invalid CSS documents or documents with stylesheets.
This means that about $ratio\% of your most popular documents were invalid.";
                }
                else
		# we didn't find as many invalid docs as requested
		{
                        $outro="Conclusion :
You asked for $max_invalid invalid HTML document but I could only find $invalid_census 
by processing (all the) $total_census document(s) in your logs. 
This means that about $ratio\% of your most popular documents were invalid.";
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
        if (($total_census == $max_documents) and ($total_census)) # we stopped because of max_documents
        {
                $outro=$outro."\nNOTE: I stopped after processing $max_documents documents:\n      Maybe you could set MaxDocuments to a higher value?";
        }
	untie %hits;                                                                  
	
	# Here is what the module will return. The hash will be sent to 
	# the output module

	my %returnhash;
	# the name of the module
	$returnhash{"name"}="CSSValidator";                                                  
	#intro
	$returnhash{"intro"}=$intro;
	#Headers for the result table
	@{$returnhash{"thead"}}= @result_head;
	# data for the results table
	@{$returnhash{"trows"}}= @result;
#	#outro
	$returnhash{"outro"}=$outro;
	return %returnhash;
}

package W3C::LogValidator::CSSValidator;

1;

__END__

=head1 NAME

W3C::LogValidator::CSSValidator - Validates CSS style sheets from Web Server logs


=head1 DESCRIPTION

This module is part of the W3C::LogValidator suite, and is used as an interface to the W3C CSS validation service.

=head1 AUTHOR

Olivier Thereaux <ot@w3.org>

=head1 SEE ALSO

W3C::LogValidator::LogProcessor, perl(1).
Up-to-date complete info at http://www.w3.org/QA/Tools/LogValidator/

=cut
