#!/usr/bin/perl -w

use strict;

use XML::SAX::Writer;
use WAP::SAXDriver::wbxml;

my $handler = new XML::SAX::Writer();
my $parser = new WAP::SAXDriver::wbxml(Handler => $handler);

my $file = $ARGV[0];
die "No input.\n"
		unless ($file);
my $io = new IO::File($file,"r");
die "Can't open $file ($!).\n"
		unless (defined $io);
my $out = $ARGV[1];
if ($out) {
	open STDOUT, "> $out"
			or die "can't open $out ($!).\n";
}

my $doc = $parser->parse(
		Source		=> {ByteStream => $io}
);

__END__

=head1 NAME

wbxmld - WBXML Disassembler

=head1 SYNOPSYS

 wbxmld I<file>

=head1 DESCRIPTION

B<wbxmld> disassembles binarized XML (WBXML) into XML.

B<wbxmld> needs XML::SAX::Writer module.

WAP Specifications, including Binary XML Content Format (WBXML)
 are available on E<lt>http://www.wapforum.org/E<gt>.

=head1 SEE ALSO

WAP::SAXDriver::wbxml, WAP::wbxml, wbxmlc

=head1 AUTHOR

Francois PERRAD, francois.perrad@gadz.org

=cut
