# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################
use Test;
use strict;
print "testing the core Log validator module... \n";
BEGIN { plan tests => 1 };
use W3C::LogValidator;
ok("1"); # If we made it this far, we're ok.
#########################

