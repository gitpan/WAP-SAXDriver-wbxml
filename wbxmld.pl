#!/usr/bin/perl -w

use strict;

use Getopt::Std;
use XML::SAX::Writer;
use WAP::SAXDriver::wbxml;

my %opts;
getopts('bp:', \%opts);

my $consumer = new XML::SAX::Writer::StringConsumer();
my $handler = new XML::SAX::Writer(Output => $consumer);
my $error = new MyErrorHandler();
my $parser = new WAP::SAXDriver::wbxml(Handler => $handler, ErrorHandler => $error, RulesPath => $opts{p});

my $file = $ARGV[0];
die "No input.\n"
		unless ($file);
my $io = new IO::File($file,"r");
die "Can't open $file ($!).\n"
		unless (defined $io);
binmode $io, ":raw";
my $out = $ARGV[1];
if ($out) {
	open STDOUT, "> $out"
			or die "can't open $out ($!).\n";
}

my $doc = $parser->parse(
		Source		=> {ByteStream => $io}
);

if ($opts{b}) {
	my @tab;
	foreach (split /(<[^>']*(?:'[^']*'[^>']*)*>)/, ${$consumer->finalize()}) {
		next unless ($_);
		pop @tab if (/^<\//);
		print @tab,$_,"\n";
		push @tab,'  ' if (/^<[^\/?!]/ and /[^\/]>$/);
	}
} else {
	print ${$consumer->finalize()};
}

package MyErrorHandler;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    return bless {}, $class;
}

sub fatal_error {
	my $self = shift;
	my ($hash) = @_;
	die __PACKAGE__,": Fatal error\n\tat position $hash->{BytePosition}.\n";
}

sub error {
	my $self = shift;
	my ($hash) = @_;
	warn __PACKAGE__,": Error: $hash->{Message}\n\tat position $hash->{BytePosition}\n";
}

sub warning {
	my $self = shift;
	my ($hash) = @_;
	warn __PACKAGE__,": Warning: $hash->{Message}\n\tat position $hash->{BytePosition}\n";
}

__END__

=head1 NAME

wbxmld - WBXML Disassembler

=head1 SYNOPSYS

wbxmld [B<-b>] [B<-p> I<path>] I<file>

=head1 OPTIONS

=over 8

=item -b

Beautify

=item -p

Specify the path of rules (the default is WAP/SAXDriver).

=back

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
