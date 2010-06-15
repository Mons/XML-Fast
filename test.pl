#!/usr/bin/env perl
use uni::perl ':dumper';
no warnings qw(internal FATAL);
use warnings qw(internal);
use Data::Dumper;
use ExtUtils::testlib;
use XML::Fast;
use XML::Bare;
use XML::Hash::LX ();
use Devel::Leak;
my $handle;
my $data;
=for rem
say dumper(XML::Hash::LX::xml2hash( q{<?xml version="1.0" encoding="cp1251" ?>
<!DOCTYPE test1 [
	<!ENTITY copy "&#38;#60;" >
]>
<test> &#x2622; &amp;'&#x44b;'+'&#1099;'+&copy;</test>} ));
exit;
say dumper( XML::Bare->new(text => '<text>&amp;</text>')->parse );
__END__
=cut
#XML::Fast::xml2hash('<!-- test -->');

#=cut
#Devel::Leak::NoteSV( $handle);
#XML::Fast::_test();
#Devel::Leak::CheckSV($handle);
#exit;
my $xml1 = q{
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
my $xml2 = q{
	<root at="key">
		<nest>
			first &amp; mid &amp; last
		</nest>
	</root>
};
my $xml3 = q{
	<root at="key">
		<nest>
			first &amp; <v>x</v> &amp; last
		</nest>
	</root>
};
my $xml4 = q{
	<root at="nb:&lt - &lt; - &#9762; - bad:&#?; - bad:&#x?; - &#x2622 - &gt;">
		nb:&lt - &lt; - &#9762; - bad:&#?; - bad:&#x?; - &#x2622 - &gt;
	</root>
	
};
my $xml5 = q{
	<root>&#9762;<sub />&#x2622</root>
};
my $bigxml;
{
no utf8;
$bigxml = "<?xml version=\"1.0\"?>".
			"<test1 a='1&amp;234-5678-9012-3456-7890'>".
				"<empty />".
				"<testi x='x' x='y' x = 'z' />".
				"<testz x='a' x='b>' x='c' / >".
				"<repeated><node>node1</node><node>node2</node><node>node3</node></repeated>".
				"<repeated1><node attr='1'>node1</node><node attr='2'>node2</node><node attr='3'>node3</node></repeated1>".
				"<test2>".
					"<test3>".
						"some text".
						"<!-- comment1 -->".
						"<!-- comment2 -->".
						"<!-- comment3 -->".
						"<![CDATA[cda это тест]]>".
						"ok1&amp;ok2&gttest".
						"<i>itest<s>istest<b>isbtest</i>sbtest</b>stest2</s>".
						"iiiiii   ".
					"</test3>".
				"</test2>".
				"<wsp>  abc  </wsp>".
				"<multy>abc&ampxyz</multy>".
			"</test1 >\n";
}
if (1){
say dumper(
	XML::Fast::xml2hash($xml4, join => undef)
);
exit if $ARGV[0] eq 'dump5';
say dumper(
	XML::Fast::xml2hash($xml5, join => undef)
);
exit if $ARGV[0] eq 'dump6';
say dumper(
	XML::Fast::xml2hash($xml2, trim => 0, join => undef)
);
exit if $ARGV[0] eq 'dump1';
say dumper(
	XML::Fast::xml2hash($xml3, join => undef)
);
exit if $ARGV[0] eq 'dump2';
say dumper(
	XML::Fast::xml2hash("<?xml version=\"1.0\"?><test>text</test>"),
);
exit if $ARGV[0] eq 'dump3';
say dumper(
	XML::Fast::xml2hash("<?xml version=\"1.0\" encoding='utf-8' ?><test>text&amp;text</test>",join=>undef),
);
exit if $ARGV[0] eq 'dump4';
say Data::Dumper::Dumper +
my $xml = XML::Fast::xml2hash($bigxml, cdata => '#', comm => '//');
exit if $ARGV[0] eq 'dump';
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
	XML::Fast::xml2hash($bigxml);
	XML::Fast::xml2hash($bigxml, join => undef);
	XML::Fast::xml2hash($bigxml, join => '');
#=cut
}

Devel::Leak::CheckSV($handle);
print "== BIG TEST END ==\n";
#}

XML::Fast::xml2hash("", trim => undef);
XML::Fast::xml2hash("<?xml version=\"1.0\"?>", trim => 0);
XML::Fast::xml2hash("<?xml version=\"1.0\"?>", trim => '');
XML::Fast::xml2hash("<?xml version=\"1.0\"?>", trim => 1);

use Test::More qw(no_plan);

is_deeply
	$data = XML::Fast::xml2hash($bigxml, cdata => '#', comm => '//'),
{
          'test1' => {
                       'empty' => '',
                       'repeated' => {
                                       'node' => [
                                                   'node1',
                                                   'node2',
                                                   'node3'
                                                 ]
                                     },
                       'repeated1' => {
                                        'node' => [
                                                    {
                                                      '-attr' => '1',
                                                      '#text' => 'node1'
                                                    },
                                                    {
                                                      '-attr' => '2',
                                                      '#text' => 'node2'
                                                    },
                                                    {
                                                      '-attr' => '3',
                                                      '#text' => 'node3'
                                                    }
                                                  ]
                                      },
                       'multy' => 'abc&xyz',
                       'wsp' => 'abc',
                       'test2' => {
                                    'test3' => {
                                                 '#' => "cda \x{44d}\x{442}\x{43e} \x{442}\x{435}\x{441}\x{442}",
                                                 '#text' => 'some textok1&ok2>testsbteststest2iiiiii',
                                                 'i' => {
                                                          '#text' => 'itest',
                                                          's' => {
                                                                   'b' => 'isbtest',
                                                                   '#text' => 'istest'
                                                                 }
                                                        },
                                                 '//' => [
                                                           ' comment1 ',
                                                           ' comment2 ',
                                                           ' comment3 '
                                                         ]
                                               }
                                  },
                       '-a' => '1&234-5678-9012-3456-7890',
                       'testz' => {
                                    '-x' => [
                                              'a',
                                              'b>',
                                              'c'
                                            ]
                                  },
                       'testi' => {
                                    '-x' => [
                                              'x',
                                              'y',
                                              'z'
                                            ]
                                  }
                     }
        }
, 'big test'
or diag explain($data),"\n";

is_deeply
	$data = xml2hash($xml2, join => '+'),
	{root => {'-at' => 'key',nest => 'first & mid & last'}},
	'join => + (2)'
or diag explain($data),"\n";

{
	is_deeply
		$data = xml2hash($xml1),
		{root => {'-at' => 'key',nest => {'#text' => 'firstmidlast',vv => '',v => ['a',{'-at' => 'a','#text' => 'b'}]}}},
		'default (1)'
	or diag explain($data),"\n";
}
{
	is_deeply
		$data = xml2hash($xml1, cdata => '#cdata'),
		{root => {'-at' => 'key',nest => {'#cdata' => 'first','#text' => 'midlast',vv => '',v => ['a',{'-at' => 'a','#text' => 'b'}]}}},
		'default (1)'
	or diag explain($data),"\n";
}
{
	is_deeply
		$data = xml2hash($xml2),
		{root => {'-at' => 'key',nest => 'first & mid & last'}},
		'default (2)'
	or diag explain($data),"\n";
}
{
	is_deeply
		$data = xml2hash($xml3),
		{root => {'-at' => 'key',nest => {'#text' => 'first && last',v => 'x'}}},
		'default (3)'
	or diag explain($data),"\n";
}
{
	is_deeply
		$data = xml2hash($xml2, join => '+'),
		{root => {'-at' => 'key',nest => 'first & mid & last'}},
		'join => + (2)'
	or diag explain($data),"\n";
}
{
	is_deeply
		$data = xml2hash($xml3, join => '+'),
		{root => {'-at' => 'key',nest => { '#text' => 'first &+& last', v => 'x' } }},
		'join => + (3)'
	or diag explain($data),"\n";
}
{
	is_deeply
		$data = xml2hash($xml1, array => ['root']),
		{root => [{'-at' => 'key',nest => {'#text' => 'firstmidlast',vv => '',v => ['a',{'-at' => 'a','#text' => 'b'}]}}]},
		'array => root (1)',
	or diag explain($data),"\n";
}
{
	is_deeply
		$data = xml2hash($xml1, array => ['nest']),
		{root => {'-at' => 'key',nest => [{'#text' => 'firstmidlast',vv => '',v => ['a',{'-at' => 'a','#text' => 'b'}]}]}},
		'array => nest (1)',
	or diag explain($data),"\n";
}
{
	is_deeply
		$data = xml2hash($xml1, array => 1),
		{root => [{'-at' => 'key',nest => [{'#text' => 'firstmidlast',vv => [''],v => ['a',{'-at' => 'a','#text' => 'b'}]}]}]},
		'array => 1 (1)',
	or diag explain($data),"\n";
}
