# Copyright (c) 2002 the World Wide Web Consortium :
#       Keio University,
#       Institut National de Recherche en Informatique et Automatique,
#       Massachusetts Institute of Technology.
# written by Olivier Thereaux <ot@w3.org> for W3C
#
# $Id: HTML.pm,v 1.1 2003/05/07 02:53:20 ot Exp $

package W3C::LogValidator::Output::HTML;
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
our $verbose = 1;
our %config;

sub new
{
        my $self  = {};
        my $proto = shift;
        my $class = ref($proto) || $proto;
	# configuration for this module
	if (@_) {%config =  %{(shift)};}
	if (defined $config{verbose}) {$verbose = $config{verbose}}
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
<h2>Results for module ".$results{'name'}."</h2>\n";
	$outputstr= $outputstr."<p>".$results{"intro"}."</p>\n" if ($results{"intro"});
	my @thead = @{$results{"thead"}};
	my @trows = @{$results{"trows"}};
	if ((@thead) or (@trows))
	{
		$outputstr= $outputstr."<table>\n";
	if (@thead)
	{
		$outputstr= $outputstr."<tr>\n";
		while (@thead)
		{
			my $header = shift (@thead);	
			$outputstr= $outputstr."<th>$header</th>";
		}
		$outputstr= $outputstr."</tr>\n";
	}
	while (@trows)
	{
		my @row=@{shift (@trows)};
		$outputstr= $outputstr."<tr>\n";
		my $tcell;
		while (@row)
		{
			$tcell= shift (@row);	
			chomp $tcell;
			$outputstr= $outputstr."<td>$tcell</td>";
		}
		$outputstr= $outputstr."</tr>\n";
	}
		$outputstr= $outputstr."</table>\n";
	}
	$outputstr= $outputstr."\n";
	$outputstr= $outputstr."<p>".$results{"outro"}."</p>\n\n" if ($results{"outro"});
	return $outputstr;	
}

sub finish                                                                            
{
# embed HTML tidbits in a full HTML file 
# and either save or output
 my $self = shift;
my ($sec,$min,$hour,$day,$mon,$year,$wday,$yday) = gmtime(time);
$mon ++; # weird 'feature': months run 0-11; days run 1-31 :-(
my $date = ($year+1900) .'-'. ($mon>9 ? $mon:"0$mon") .'-'. ($day>9 ? $day:"0$day");

 my $result_string = '<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
<title>LogValidator results</title>
<link rel="Stylesheet" href="http://www.w3.org/QA/2002/12/qa4.css" />
</head>
<body>
<h1>Log Validator results</h1>'."
<p>Generated on $date at $hour:$min:$sec GMT.</p>";

       if (@_)
        {
                my $tmp_result_string = shift;
		$result_string = $result_string.$tmp_result_string;
	}

$result_string = $result_string.'
</body>
</html>';

	if (defined $config{OutputTo}) 
	{
		my $filetosave = $config{OutputTo};
		open (HTMLOUT, "> $filetosave")
		||  print STDERR "could not open file $filetosave for saving : $!";
		print HTMLOUT $result_string;
		close HTMLOUT;
	}
	else 
	{
		print $result_string;
	}
}	

package W3C::LogValidator::Output::HTML;

1;

__END__

=head1 NAME

W3C::LogValidator::Output::HTML - HTML Output for the Log Validator

=head1 SYNOPSIS

  use  W3C::LogValidator::HTMLOutput;

=head1 DESCRIPTION

This module is part of the W3C::LogValidator suite, and outputs
the result of the log processing and validation in HTML format.

=head1 AUTHOR

Olivier Thereaux <ot@w3.org>

=head1 SEE ALSO

W3C::LogValidator, perl(1).
Up-to-date complete info at http://www.w3.org/QA/Tools/LogValidator/

=cut
