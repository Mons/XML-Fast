#!/use/bin/perl -w

use strict;
use Test::More;
BEGIN {
	my $add = 0;
	eval {require Test::NoWarnings;1 }
		and *had_no_warnings = \&Test::NoWarnings::had_no_warnings
		or  *had_no_warnings = sub {} and diag "Test::NoWarnings missed, skipping no warnings test";
	#plan tests => 26 + $add;
	eval {require Data::Dumper;Data::Dumper::Dumper(1)}
		and *dd = sub ($) { Data::Dumper->new([$_[0]])->Indent(0)->Terse(1)->Quotekeys(0)->Useqq(1)->Purity(1)->Dump }
		or  *dd = \&explain;
}

use XML::Fast 'xml2hash';

sub dies_ok(&;@) {
	my $code = shift;
	my $name = pop || 'line '.(caller)[2];
	my $qr = shift;
	local $@;
	if( eval { $code->(); 1} ) {
		fail $name;
	} else {
		if ($qr) {
			like $@,$qr,"$name - match ok";
		} else {
			diag "died with $@";
		}
		pass $name;
	}
}

dies_ok { xml2hash('<--') } qr//, 'unbalanced comment';

had_no_warnings();
done_testing();