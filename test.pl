# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################
use Test;
use strict;
BEGIN { plan tests => 1 };
use W3C::LogValidator::LogProcessor;
ok(1); # If we made it this far, we're ok.
#########################

