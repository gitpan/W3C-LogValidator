# Copyright (c) 2002 the World Wide Web Consortium :
#	Keio University,
#	Institut National de Recherche en Informatique et Automatique,
#	Massachusetts Institute of Technology.
# written by Olivier Thereaux <ot@w3.org> for W3C
#
# $Id: Config.pm,v 1.1 2003/05/07 02:26:07 ot Exp $

package W3C::LogValidator::Config;
use strict;

require Exporter;
our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.1';

our $config_filename;
our %conf;

###########################
# usual package interface #
###########################
sub new
{
        my $self  = {};
        my $proto = shift;
        my $class = ref($proto) || $proto;
        $self->{NAME}   = undef;
        $self->{SERVERADMIN}    = undef;
        $self->{DOCUMENTROOT}   = undef;
        $self->{LOGFILES}       = undef;
        $self->{LOGFORMAT}      = undef;
        $self->{LOGTYPE}        = undef;
        $self->{MODULES}        = undef;
        $self->{MAX_INVALID}    = undef;
	$self->{DIRECTORYINDEX}	= undef;
        bless($self, $class);
	# default values

	# did we get a config file as an argument?
	if (@_)
	{
		$config_filename = shift;
		$self->config_file;
	}
	else
	{
		$self->config_default;
	}
#	$self->give_config;	# debug
        return $self;
}

sub configure
{
	return %conf;
}

sub config_default
{
	use Sys::Hostname qw(hostname);
	my $self = shift;
	# setting default values for LogProcessor
	if (!exists $conf{LogProcessor}{DirectoryIndex})
	{	
		$conf{LogProcessor}{DirectoryIndex}=("index.html index.htm index");
	}
	if (!exists $conf{LogProcessor}{MaxInvalid})
	{
		$conf{LogProcessor}{MaxInvalid}=10;
	}
	if (!exists $conf{LogProcessor}{ServerName})
	{
		$conf{LogProcessor}{ServerName}=hostname();
	}
	if (!exists $conf{LogProcessor}{DocumentRoot})
	{
		$conf{LogProcessor}{DocumentRoot}="/var/www/";
	}
	if (!exists $conf{LogProcessor}{LogFiles})
	{	
		push @{$conf{LogProcessor}{LogFiles}}, "/var/log/apache/access.log";
		$conf{LogProcessor}{LogType}{"/var/log/apache/access.log"}="common";
	}

	if (!exists $conf{LogProcessor}{UseValidationModule})
	{
		#adding modules and options for the modules
		push @{$conf{LogProcessor}{UseValidationModule}}, "W3C::LogValidator::HTMLValidator";
		push @{$conf{LogProcessor}{UseValidationModule}}, "W3C::LogValidator::Basic";
		$conf{"W3C::LogValidator::HTMLValidator"}{max_invalid}=10;
	}
	# adding default limit  - useful for very (too) big logfiles
	if (!exists $conf{LogProcessor}{EntriesPerLogfile})
	{
		$conf{LogProcessor}{EntriesPerLogfile}=100000; 
	}
}



sub config_file
{
	my $self = shift;
	use Config::General;
	my $config_read = new Config::General(-ConfigFile => "$config_filename")
	|| die "could not load config $config_filename : $!";
	# using C::General to read logfile
	my %tmpconf = $config_read->getall;
	# extracting modules config
	# Config::General will give the hash this structure

	# HASH {
	# foo -> valfoo
	# bar -> valbar
	# Module {
	#	module1 {
	#			ga -> valga
	#		}
	#	}
	# }

	# 	and we want 

	
	# HASH {
	# LogProcessor {
	#	foo -> valfoo
	#	bar -> valbar
	#	}
	# module1 {
	#	ga -> valga
	#	}
	# }

	
	# so First we extract what's in the Module subhash
	if (exists($tmpconf{Module}))
	{
		%conf = %{$tmpconf{Module}};
	}
	# remove it
	delete $tmpconf{Module};
	# and merging with the global values we put in the LogProcessor subhash
	%{$conf{LogProcessor}} = %tmpconf;

	# specific action is needed for "CustomLog"
	if (exists($tmpconf{CustomLog}))
	{
		# if there are several log files, $tmpconf{CustomLog} is an array
		if (defined @{ $tmpconf{CustomLog} })
		{ 
		   foreach my $customlog (@{ $tmpconf{CustomLog} })
		   {
			$_ = $customlog;
			if (/^(.*) (.*)$/) 
			{
				# only supported (so far) is the syntax:
				# CustomLog path/file nickname
				push @{$conf{LogProcessor}{LogFiles}}, $1;
				$conf{LogProcessor}{LogType}{$1}=$2;
			}
		   }

		}
		else # one log file, $tmpconf{CustomLog} is not an array
		{ 
			$_ = $tmpconf{CustomLog};
			if (/^(.*) (.*)$/) 
			{
				push @{$conf{LogProcessor}{LogFiles}}, $1;
				$conf{LogProcessor}{LogType}{$1}=$2;			
			}
		}
		delete $conf{LogProcessor}{CustomLog};
	}
	
	# add default values for variables not included in the config file
	$self->config_default();	
}

1;
