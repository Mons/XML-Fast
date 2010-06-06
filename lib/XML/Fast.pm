package XML::Fast;

use 5.012000;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use XML::Fast ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	xml2hash
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('XML::Fast', $VERSION);

sub xml2hash($;%) {
	my $xml = shift;
	my %args = (
		order  => 0,
		attr   => '-',
		text   => '#text',
		join   => '',
		trim   => 1,
		cdata  => undef,
		comm   => undef,
		cdata  => '#',
		comm   => '//',
		@_
	);
	_xml2hash($xml,\%args);
}

# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

XML::Fast - Perl extension for blah blah blah

=head1 SYNOPSIS

  use XML::Fast;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for XML::Fast, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Vladimir Perepelitsa, E<lt>mons@park.rambler.ruE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Vladimir Perepelitsa

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.12.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
