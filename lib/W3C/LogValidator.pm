# Copyright (c) 2002 the World Wide Web Consortium :
#       Keio University,
#       Institut National de Recherche en Informatique et Automatique,
#       Massachusetts Institute of Technology.
# written by Olivier Thereaux <ot@w3.org> for W3C
#
# $Id: LogValidator.pm,v 1.2 2003/05/07 02:52:25 ot Exp $

package W3C::LogValidator;
use strict;

require Exporter;
our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.2';

our %config;
our $output="";
our $config_filename = undef;
our $verbose;
our %cmdline_conf;
our %hits; # hash URI->hits
our $output_proc;

###########################
# usual package interface #
###########################
sub new
{
	my $self  = {};
        my $proto = shift;
        my $class = ref($proto) || $proto;

	# server config is imported from the config module
        use W3C::LogValidator::Config;
	if (@_)
	{
		$config_filename = shift;
#		print "using config filename  $config_filename \n"; #debug
		if ($config_filename)
		{
	        	%config = W3C::LogValidator::Config->new($config_filename)->configure();
		}
		else
		{
			%config = W3C::LogValidator::Config->new()->configure();
		}
	}
	else
	{ %config = W3C::LogValidator::Config->new()->configure(); }

	# processing other options given at the command line
	if (@_)
	{
	%cmdline_conf= %{(shift)};
	}
	# verbosity : overriding config if given at command line
	if (defined($cmdline_conf{verbose}))
	{
		($config{LogProcessor}{verbose}) = $cmdline_conf{verbose};
		$verbose = $cmdline_conf{verbose};
	}
	# setting default verbosity if not given
	elsif (! defined($config{LogProcessor}{verbose}) )
	{
		($config{LogProcessor}{verbose}) = 1;
		$verbose = 1;
	}
	# output : overriding config if given at command line
	if ( defined($cmdline_conf{"UseOutputModule"}) )
	{
		$config{LogProcessor}{UseOutputModule} = $cmdline_conf{UseOutputModule};
	}
	elsif (! defined($config{LogProcessor}{UseOutputModule}))
	{
		$config{LogProcessor}{UseOutputModule} = "W3C::LogValidator::Output::Raw";
	}
	
	# output to file 
	# no "default value, will output to console if not set!
	if ( defined($cmdline_conf{"OutputTo"} ) )
	{
		$config{LogProcessor}{OutputTo} = $cmdline_conf{"OutputTo"};
	}

	# same for e-mail address to send to 
	# overrding conf file info with cmdline info
	if ( defined($cmdline_conf{"ServerAdmin"}) )	
	{
		$config{LogProcessor}{"ServerAdmin"} = $cmdline_conf{"ServerAdmin"};
	}

	use File::Temp qw/ /;
	my $tmpdir = File::Spec->tmpdir;
	$config{LogProcessor}{tmpfile} = File::Temp::tempnam( $tmpdir, "LogValidator-" );
	bless($self, $class);
	return $self;
}


sub sorted_uris
{
	my $self = shift;
	print "sorting logs: " if $verbose; # non-quiet mode
	my @uris = sort { $hits{$b} <=> $hits{$a} }
		keys %hits;

	my $theuri;
	my  $theuri_hit;
	my @theuriarry;
	@theuriarry = @uris;
	while ( (@theuriarry) and ($verbose > 1))
	{
		$theuri = shift (@theuriarry);
		$theuri_hit = $hits{$theuri};
		print "	$theuri $theuri_hit\n";
	}


	print "Done!\n" if $verbose; # non-quiet mode
	return @uris;
}

###################
# Server routines #
###################

sub add_uri
# usage $self->add_uri('http://foobar')
{
	my $self = shift;
	if (@_)
	{
		my $uri = shift;
		if ( exists($hits{$uri}) )
		{
			$hits{$uri} = $hits{$uri}+1;
		}
		else
		{ $hits{$uri} = 1 }
	}
}

sub read_logfiles
# just looping
{
	my $self = shift;
	my $current_logfile;
	use DB_File;
	my $tmp_file = $config{LogProcessor}{tmpfile};
	tie (%hits, 'DB_File', "$tmp_file") ||
	die ("Cannot create or open $tmp_file");
	
	print "Reading logfiles: " if ($verbose); #non-quiet mode
	print "\n" if ($verbose >1); # verbose or above, we'll have details so linebreak
	my @logfiles = @{$config{LogProcessor}{LogFiles}};
	foreach $current_logfile (@logfiles)
	{
		$self->read_logfile($current_logfile);
	}
	untie %hits;
	print "Done! \n" if ($verbose); #non-quiet mode

}



sub read_logfile
#read logfile, push uris  one by one with the appropriate sub
{
	my $self = shift;
	my $tmp_record;
	my $entriesperlogfile = $config{LogProcessor}{EntriesPerLogfile};
	my $entriescounter=0;
	if (@_)
	{
		my $logfile = shift;
		if (open (LOGFILE, "$logfile")) {
			print "	$logfile...\n" if ($verbose > 1); # verbose or above
			$entriescounter=0;
			while ( (($entriescounter < $entriesperlogfile ) or (!$entriesperlogfile)) # limit number of entries
			and ($tmp_record = <LOGFILE>)) 
			      
	 		{
				$tmp_record =~ chomp;
				my $logtype = $config{LogProcessor}{LogType}{$logfile};
				if ($tmp_record) # not a blank line
				{
					$tmp_record = $self->find_uri($tmp_record, $logtype);
					#print "$tmp_record \n" if ($verbose >2);
					$self->add_uri($tmp_record);
				}
				$entriescounter++;
			}
			close LOGFILE;
		} elsif ($logfile) {
			die "could not open log file $logfile : $!";
		}
	}
}

sub find_uri
# finds the "real" URI from a log record
{
	my $self = shift;
	if (@_)
	{
		my $tmprecord = shift;
		my @record_arry;
		@record_arry = split(" ", $tmprecord);
		# hardcoded to most apache log formats, included common and combined
		# for the moment... TODO
		my $logtype = shift;
		# print "log type $logtype" if ($verbose > 2);
		if ($logtype eq "plain")
		{
			$tmprecord = $record_arry[0];
		}
		else #common combined or full
		{
			$tmprecord = $record_arry[6];
			$tmprecord = $self->remove_duplicates($tmprecord);
			$tmprecord = join ("",'http://',$config{LogProcessor}{ServerName},$tmprecord);
		}
	return $tmprecord;
	}
}

sub remove_duplicates
# removes "directory index" suffixes such as index.html, etc
# so that http://foobar/ and http://foobar/index.html be counted as one resource
{
	my $self = shift;
	my $tmprecord;
	if (@_) { $tmprecord = shift;}
	my $index_file;
	foreach $index_file (split (" ",$config{LogProcessor}{DirectoryIndex}))
	{
		$tmprecord =~ s/$index_file$// if ($tmprecord);
	}
	return $tmprecord;

}



sub hit
{
	my $self = shift;
	my $uri=undef;
	if (@_) {$uri=shift}
	return $hits{$uri};
}

sub config_module
{
	my $self = shift;
	my $module_used; #= undef;
	if (@_)
	{ 	
		$module_used = shift;
	}
	my %tmpconfig = %{$config{LogProcessor}};
	#add module specific variables, override if necessary.
	if ( ($module_used) and (defined ($config{$module_used})))
	{	
		foreach my $modkey (keys %{$config{$module_used}})
		{
			if ( $config{$module_used}{$modkey} ) 
			{
				$tmpconfig{$modkey} = $config{$module_used}{$modkey}
			}
		}
	}
	return %tmpconfig;
}
	

sub use_modules
{
	my $self = shift;
	my @modules;
	# the value of the hash may be an array or a single value, 
	# we have to check this
	if (defined @{ $config{LogProcessor}{UseValidationModule} }) 
	{
		@modules = @{$config{LogProcessor}{UseValidationModule}} 	
	} 
	else # single entry that we push in an array
	{
		push @modules, $config{LogProcessor}{UseValidationModule};
	}
	foreach my $module_to_use (@modules)
	{
		eval "use $module_to_use";
		my $process_module;
		my %mod_config=$self->config_module($module_to_use);
		$process_module = $module_to_use->new(\%mod_config);
	#	$process_module->uris($self->sorted_uris); # not used anymore
		my %results = $process_module->process_list;
		

		# We're applying the output module and getting its (potential) output 
		my $output_tmp = $output_proc->output(\%results);
		$output = $output.$output_tmp;
		# TODO maybe make this a hash, one output string per output module used
		# that would allow us to have several output modules at the time... 
		# is this very useful?
	}
}


sub process
# this is the main routine
# processes the logfile, sorts the uris, and uses the chosen modules
{
	my $self = shift;
	if ($verbose > 2) #debug
	{
		print "showing general config : \n";
		foreach my $key ( keys %config)
		{
			my %modname = %{$config{$key}};
			print "Module	$key\n";
			foreach my $modkey (keys %{$config{$key}})
			{
				my $value = $config{$key}{$modkey};
				print " $modkey $value\n";
			}
		}
		print "End of config\n\n"
	}
	

	$self->read_logfiles;
	my $outputmodule = $config{LogProcessor}{UseOutputModule};
	eval "use $outputmodule";
	$output_proc = $outputmodule->new(\%{$config{LogProcessor}});
	$self->use_modules;
	$output_proc->finish($output);
	
}

package W3C::LogValidator;
1;

__END__

=head1 NAME

W3C::LogValidator - Main module for LogValidator

=head1 SYNOPSIS

use W3C::LogValidator;

# parse config and process logs 
my $logprocessor = W3C::LogValidator->new("sample.conf");
$logprocessor->process;

# alternatively (use default config and process logs)
my $logprocessor = W3C::LogValidator->new;
$logprocessor->process;


=head1 DESCRIPTION

This module is the main module for the LogValidator set.
Its role is to process the log files, give the results to the validation modules,
get their output back, and send this to the output module(s).


=head1 AUTHOR

Olivier Thereaux <ot@w3.org> for The World Wide Web Consortium

=head1 SEE ALSO

perl(1).
Up-to-date complete info at http://www.w3.org/QA/Tools/LogValidator/

=cut

