# Copyright (c) 2002 the World Wide Web Consortium :
#       Keio University,
#       Institut National de Recherche en Informatique et Automatique,
#       Massachusetts Institute of Technology.
# written by Olivier Thereaux <ot@w3.org> for W3C
#
# $Id: MailOutput.pm,v 1.1 2003/03/28 13:36:03 ot Exp $

package W3C::LogValidator::MailOutput;
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
# for this module, that means send e-mail to the specified maintainer
 my $self = shift;
        if (@_)
        {
                my $result_string = shift;
		my ($sec,$min,$hour,$day,$mon,$year,$wday,$yday) = gmtime(time);
		$mon ++; # weird 'feature': months run 0-11; days run 1-31 :-(
		my $date = ($year+1900) .'-'. ($mon>9 ? $mon:"0$mon") .'-'. ($day>9 ? $day:"0$day");

		if (defined $config{"ServerAdmin"})
		{
			my $add = $config{"ServerAdmin"};
			use Mail::Sendmail;
			my %mail = (To      => $add,
			From    =>  "LogValidator <$add>",
			Subject => "Logvalidator results : $date at $hour:$min GMT",
			'X-Mailer' => "Mail::Sendmail version $Mail::Sendmail::VERSION",
			Message => $result_string );
			print "Sending Mail to $add...\n" if ($verbose >1 );
			Mail::Sendmail::sendmail(%mail) or print STDERR $Mail::Sendmail::error;
		}
		else { print $result_string; }
	}
	

}

package W3C::LogValidator::MailOutput;

1;

__END__

=head1 NAME

W3C::LogValidator::MailOutput - e-mail output module for the Log Validator

=head1 SYNOPSIS


=head1 DESCRIPTION

This module is part of the W3C::LogValidator suite, and sends the results
of the log processing and validation as an e-mail message to the webmaster

=head1 AUTHOR

Olivier Thereaux <ot@w3.org>

=head1 SEE ALSO

W3C::LogValidator::LogProcessor, perl(1).

=cut
