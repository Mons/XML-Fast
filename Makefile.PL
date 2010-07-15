use 5.008008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	NAME              => 'XML::Fast',
	VERSION_FROM      => 'lib/XML/Fast.pm', # finds $VERSION
	ABSTRACT_FROM     => 'lib/XML/Fast.pm', # retrieve abstract from module
	PREREQ_PM         => { 'Encode' => 0 }, # e.g., Module::Name => 1.1
	AUTHOR            => 'Mons Anderson <mons@cpan.org>',
	LIBS              => [''], # e.g., '-lm'
	DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
	INC               => '-I.', # e.g., '-I. -I/usr/include/other'
	#CCFLAGS           => '-Wunused',
	CCFLAGS           => '-Wunused -std=c99',
	OBJECT            => 'Fast.o xmlfast.o', # link all the C files too
);
