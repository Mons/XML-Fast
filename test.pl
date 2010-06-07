#!/usr/bin/env perl
use uni::perl ':dumper';
#no warnings 'internal';
use ExtUtils::testlib;
use XML::Fast;
use Devel::Leak;
#XML::Fast::xml2hash('<!-- test -->');
#__END__
Devel::Leak::NoteSV(my $handle);
XML::Fast::_test();
Devel::Leak::CheckSV($handle);
#exit;
#say dumper +
{
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
}
Devel::Leak::NoteSV(my $handle);

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
			"</test1 >\n");
undef $xml;

Devel::Leak::CheckSV($handle);

XML::Fast::xml2hash("", trim => undef);
XML::Fast::xml2hash("<?xml version=\"1.0\"?>", trim => 0);
XML::Fast::xml2hash("<?xml version=\"1.0\"?>", trim => '');
XML::Fast::xml2hash("<?xml version=\"1.0\"?>", trim => 1);
