#!/use/bin/perl -w

use strict;
use Test::More;
BEGIN {
	my $add = 0;
	eval {require Test::NoWarnings;Test::NoWarnings->import; ++$add; 1 }
		or diag "Test::NoWarnings missed, skipping no warnings test";
	plan tests => 3 + $add;
	eval {require Data::Dumper;Data::Dumper::Dumper(1)}
		and *dd = sub ($) { Data::Dumper->new([$_[0]])->Indent(0)->Terse(1)->Quotekeys(0)->Useqq(1)->Purity(1)->Dump }
		or  *dd = \&explain;
}

use XML::Fast 'xml2hash';

# Parsing

our $xml1 = q{
	<root at="key">
		<!-- test -->
		<nest>
			<![CDATA[first]]>
			<v>a</v>
			mid
			<v at="a">b</v>
			<vv></vv>
			last
		</nest>
	</root>
};

our $xml2 = q{
	<root at="key">
		<nest>
			first &amp; mid &amp; last
		</nest>
	</root>
};

our $xml3 = q{
	<root at="key">
		<nest>
			first &amp; <v>x</v> &amp; last
		</nest>
	</root>
};


our $data;
{
	is_deeply
		$data = xml2hash($xml1, text => undef, attr => undef, trim => 0, ),
		{root => {'at' => 'key',nest => {vv => '',v => ['',{'at' => 'a'}]}}},
		'default (1)'
	or diag dd($data),"\n";
}
{
	is_deeply
		$data = xml2hash($xml2, text => undef, attr => undef, trim => 0, ),
		{root => {'at' => 'key',nest => ''}},
		'default (2)'
	or diag dd($data),"\n";
}
{
	is_deeply
		$data = xml2hash($xml3, text => undef, attr => undef, trim => 0, ),
		{root => {'at' => 'key',nest => {v => ''}}},
		'default (3)'
	or diag dd($data),"\n";
}
