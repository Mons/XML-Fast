#!/usr/bin/env perl
use uni::perl ':dumper';
no warnings qw(internal FATAL);
use warnings qw(internal);
use ExtUtils::testlib;
use XML::Fast;
use Devel::Leak;
my $handle;
#XML::Fast::xml2hash('<!-- test -->');
#__END__
#Devel::Leak::NoteSV( $handle);
#XML::Fast::_test();
#Devel::Leak::CheckSV($handle);
#exit;

if (1){
say dumper(
	XML::Fast::xml2hash("<?xml version=\"1.0\"?><test>text</test>"),
);
say dumper(
	XML::Fast::xml2hash("<?xml version=\"1.0\"?><test>text&amp;text</test>",join=>undef),
);
say dumper +
my $xml = XML::Fast::xml2hash("<?xml version=\"1.0\"?>".
			"<test1 a='1&amp;234-5678-9012-3456-7890'>".
				"<testi x='x' x='y' x = 'z' />".
				"<testz x='a' x='b>' x='c' / >".
				"<test2>".
					"<test3>".
						"some text".
						"<!-- comment1 -->".
						"<!-- comment2 -->".
						"<!-- comment3 -->".
						"<![CDATA[cda]]>".
						"ok1&amp;ok2&gttest".
						"<i>test<b>test</i>test</b>".
						"iiiiii   ".
					"</test3>".
				"</test2>".
				"<wsp>  abc  </wsp>".
				"<multy>abc&ampxyz</multy>".
			"</test1 >\n", trim => 1, cdata => undef, join => '');
#exit;
}

=for rem
print "== SMALL TEST ==\n";
Devel::Leak::NoteSV($handle);

for (1..2) {
	XML::Fast::xml2hash("<?xml version=\"1.0\"?><test>text&amp;text</test>",join=>undef);
	XML::Fast::xml2hash("<?xml version=\"1.0\"?><test>text</test>");
}
Devel::Leak::CheckSV($handle);
print "== SMALL TEST END ==\n";
if (@ARGV[0] eq 'big') {
=cut
print "== BIG TEST ==\n";
Devel::Leak::NoteSV($handle);

for (1..5) {
#=for rem
	XML::Fast::xml2hash("<?xml version=\"1.0\"?>".
			"<test1 a='1&amp;234-5678-9012-3456-7890'>".
				"<testi x='x' x='y' x = 'z' />".
				"<testz x='a' x='b>' x='c' / >".
				"<test2>".
					"<test3>".
						"some text".
						"<!-- comment1 -->".
						"<!-- comment2 -->".
						"<!-- comment3 -->".
						"<![CDATA[cda]]>".
						"ok1&amp;ok2&gttest".
						"<i>test<b>test</i>test</b>".
						"iiiiii   ".
					"</test3>".
				"</test2>".
				"<wsp>  abc  </wsp>".
				"<multy>abc&ampxyz</multy>".
			"</test1 >\n");
#=cut
}

Devel::Leak::CheckSV($handle);
print "== BIG TEST END ==\n";
#}

XML::Fast::xml2hash("", trim => undef);
XML::Fast::xml2hash("<?xml version=\"1.0\"?>", trim => 0);
XML::Fast::xml2hash("<?xml version=\"1.0\"?>", trim => '');
XML::Fast::xml2hash("<?xml version=\"1.0\"?>", trim => 1);
