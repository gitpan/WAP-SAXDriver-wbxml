#
# WAP::SAXDriver::wbxml.pm
#

# glue of the methods new, parse and location comes from Ken MacLeod's
# XML::Parser::PerlSAX and the canvas of the documentation.

use strict;

package WAP::SAXDriver::wbxml;

use I18N::Charset;
use IO::File;
use IO::String;
use UNIVERSAL;

use vars qw($VERSION $default_rules $rules);

$VERSION = "1.02";

sub new {
	my $type = shift;
	my $self = (@_ == 1) ? shift : { @_ };

	return bless($self, $type);
}

sub parse {
	my $self = shift;

	die __PACKAGE__,": parser instance ($self) already parsing\n"
			if (defined $self->{ParseOptions});

##	# If there's one arg and it has no ref, it's a string
##	my $args;
##	if (scalar (@_) == 1 && !ref($_[0])) {
##		$args = { Source => { String => shift } };
##	} else {
##		$args = (scalar (@_) == 1) ? shift : { @_ };
##	}
	my $args = (scalar (@_) == 1) ? shift : { @_ };

	my $parse_options = { %$self, %$args };
	$self->{ParseOptions} = $parse_options;

	# ensure that we have at least one source
	if (!defined $parse_options->{Source}
		|| !(defined $parse_options->{Source}{String}
		     || defined $parse_options->{Source}{ByteStream})) {
##		     || defined $parse_options->{Source}{SystemId})) {
		die __PACKAGE__,": no source defined for parse\n";
	}

	# assign default Handler to any undefined handlers
	if (defined $parse_options->{Handler}) {
		$parse_options->{DocumentHandler} = $parse_options->{Handler}
				if (!defined $parse_options->{DocumentHandler});
		$parse_options->{DTDHandler} = $parse_options->{Handler}
				if (!defined $parse_options->{DTDHandler});
		$parse_options->{ErrorHandler} = $parse_options->{Handler}
				if (!defined $parse_options->{ErrorHandler});
	}

	if (defined $parse_options->{DocumentHandler}) {
		# cache DocumentHandler in self for callbacks
		$self->{DocumentHandler} = $parse_options->{DocumentHandler};
	}

	if (defined $parse_options->{DTDHandler}) {
		# cache DTDHandler in self for callbacks
		$self->{DTDHandler} = $parse_options->{DTDHandler};
	}

	if (defined $parse_options->{ErrorHandler}) {
		# cache ErrorHandler in self for callbacks
		$self->{ErrorHandler} = $parse_options->{ErrorHandler};
	}

	if (defined $self->{ParseOptions}{Source}{ByteStream}) {
		die __PACKAGE__,": Not an IO::Handle\n"
				unless ($self->{ParseOptions}{Source}{ByteStream}->isa('IO::Handle'));
		$self->{io_handle} = $self->{ParseOptions}{Source}{ByteStream};
	} elsif (defined $self->{ParseOptions}{Source}{String}) {
		$self->{io_handle} = new IO::String($self->{ParseOptions}{Source}{String});
##	} elsif (defined $self->{ParseOptions}{Source}{SystemId}) {
##		my $filename = $self->{ParseOptions}{Source}{SystemId};
##		$self->{io_handle} = new IO::File($filename,"r");
##		die __PACKAGE__,": Couldn't open $filename:\n$!"
##				unless (defined $self->{io_handle});
	}

	if ($self->{ParseOptions}{UseOnlyDefaultRules}) {
		$self->{Rules} = undef;
	} else {
		unless (defined $rules) {
			my $path = $INC{'WAP/SAXDriver/wbxml.pm'};
			$path =~ s/wbxml\.pm$//i;
			my $infile = $path . 'wbrules.pl';
			require $infile;
		}
		$self->{Rules} = $rules;
	}

	my $result = $self->_parse();

	# clean up parser instance
	delete $self->{io_handle};
	delete $self->{ParseOptions};
	delete $self->{DocumentHandler};
	delete $self->{DTDHandler};
	delete $self->{ErrorResolver};

	return $result;
}

sub location {
	my $self = shift;

	my $pos = $self->{io_handle}->tell();

	my @properties = (
		ColumnNumber	=> $pos,
		LineNumber		=> 1,
		BytePosition	=> $pos
	);

	push (@properties, PublicId => $self->{PublicId})
			if (defined $self->{PublicId});

	return { @properties };
}

###############################################################################

use integer;

# Global tokens
use constant SWITCH_PAGE  	=> 0x00;
use constant _END			=> 0x01;
use constant ENTITY			=> 0x02;
use constant STR_I			=> 0x03;
use constant LITERAL		=> 0x04;
use constant EXT_I_0		=> 0x40;
use constant EXT_I_1		=> 0x41;
use constant EXT_I_2		=> 0x42;
use constant PI				=> 0x43;
use constant LITERAL_C		=> 0x44;
use constant EXT_T_0		=> 0x80;
use constant EXT_T_1		=> 0x81;
use constant EXT_T_2		=> 0x82;
use constant STR_T			=> 0x83;
use constant LITERAL_A		=> 0x84;
use constant EXT_0			=> 0xC0;
use constant EXT_1			=> 0xC1;
use constant EXT_2			=> 0xC2;
use constant OPAQUE			=> 0xC3;
use constant LITERAL_AC		=> 0xC4;
# Global token masks
use constant NULL			=> 0x00;
use constant HAS_CHILD		=> 0x40;
use constant HAS_ATTR		=> 0x80;
use constant TAG_MASK		=> 0x3F;
use constant ATTR_MASK		=> 0x7F;

sub _parse {
	my $self = shift;

	$self->{PublicId} = undef;
	$self->{Encoding} = undef;
	$self->{App} = undef;

	if ($self->{DocumentHandler}->can('set_document_locator')) {
		$self->{DocumentHandler}->set_document_locator( {		# fire
				Locator		=> $self
		} );
	}
	if ($self->{DocumentHandler}->can('start_document')) {
		$self->{DocumentHandler}->start_document( { } );		# fire
	}

	my $version = $self->get_version();
	$self->get_publicid();
	$self->get_charset();
	if (	    !defined $self->{Encoding}
			and exists $self->{ParseOptions}{Source}{Encoding} ) {
		$self->{Encoding} = $self->{ParseOptions}{Source}{Encoding};
	}
	$self->get_strtbl();
	$self->{PublicId} = $self->get_str_t($self->{publicid_idx})
			if (exists $self->{publicid_idx});
	$self->{App} = $self->{Rules}->{App}{$self->{PublicId}}
			if (exists $self->{Rules}->{App}{$self->{PublicId}});

	if (exists $self->{Encoding}) {
		if ($self->{DTDHandler}->can('xml_decl')) {
			$self->{DTDHandler}->xml_decl( {					# fire
					Version			=> "1.0",
					Encoding		=> $self->{Encoding},
					Standalone		=> undef,
					VersionWBXML	=> $version,
					PublicId		=> $self->{PublicId}
			} );
		}
	}

	my $rc = $self->body();
	my $end = undef;
	if ($self->{DocumentHandler}->can('end_document')) {
		$end = $self->{DocumentHandler}->end_document( { } );
	}

	unless (defined $rc) {
		my $pos = $self->{io_handle}->tell();
		if ($self->{ErrorHandler}->can('fatal_error')) {
			$self->{ErrorHandler}->fatal_error( {
					Message			=> "",
					PublicId		=> $self->{PublicId},
					ColumnNumber	=> $pos,
					LineNumber		=> 1,
					BytePosition	=> $pos
			} );
		} else {
			die __PACKAGE__,": Fatal error  at position $pos\n";
		}
	}

	# clean up parser instance
	delete $self->{PublicId};
	delete $self->{Encoding};
	delete $self->{App};
	delete $self->{publicid_idx};
	delete $self->{io_strtbl} if (exists $self->{io_strtbl});

	return $end;
}

sub getmb32 {
	my $self = shift;
	my $byte;
	my $val = 0;
	my $nb = 0;
	do {
		$nb ++;
		return undef unless ($nb < 6);
		my $ch = $self->{io_handle}->getc();
		return undef unless (defined $ch);
		$byte = ord $ch;
		$val <<= 7;
		$val += ($byte & 0x7f);
	}
	while (0 != ($byte & 0x80));
	return $val
}

sub get_version {
	my $self = shift;
	my $ch = $self->{io_handle}->getc();
	return undef unless (defined $ch);
	my $v = ord $ch;
	return (1 + $v / 16) . '.' . ($v % 16);
}

sub get_publicid {
	my $self = shift;
	my $publicid = $self->getmb32();
	return undef unless (defined $publicid);
	if ($publicid) {
		if (exists $self->{Rules}->{PublicIdentifier}{$publicid}) {
			$self->{PublicId} = $self->{Rules}->{PublicIdentifier}{$publicid};
		} else {
			$self->warning("PublicId-$publicid unreferenced");
			$self->{PublicId} = "PublicId-$publicid";
		}
	} else {
		$self->{publicid_idx} = $self->getmb32();
	}
}

sub get_charset {
	my $self = shift;
	my $charset = $self->getmb32();
	return undef unless (defined $charset);
	if ($charset != 0) {
		my $default_charset = {
		# here, only built-in encodings of Expat.
		# MIBenum	=>  iana name
			3		=> "ANSI_X3.4-1968",	# US-ASCII
			4		=> "ISO_8859-1:1987",
			106		=> "UTF-8"
		};
		if (exists $default_charset->{$charset}) {
			$self->{Encoding} = $default_charset->{$charset};
		} elsif (defined I18N::Charset::mib_to_charset_name($charset)) {
			$self->{Encoding} = I18N::Charset::mib_to_charset_name($charset);
		} else {
			$self->{Encoding} = "MIBenum-$charset";
			$self->warning("$self->{Encoding} unreferenced");
		}
	}
}

sub get_strtbl {
	my $self = shift;
	my $len = $self->getmb32();
	if ($len) {
		my $str;
		$self->{io_handle}->read($str,$len);
		$self->{io_strtbl} = new IO::String($str);
	}
}

sub get_str_t {
	my $self = shift;
	my ($idx) = @_;
	return undef unless (defined $idx);
	return undef unless (exists $self->{io_strtbl});
	$self->{io_strtbl}->setpos($idx);
	my $str = '';
	my $ch = $self->{io_strtbl}->getc();
	return undef unless (defined $ch);
	while (ord $ch != 0) {
		$str .= $ch;
		$ch = $self->{io_strtbl}->getc();
		return undef unless (defined $ch);
	}
	return $str;
}

sub body {
	my $self = shift;
	my $rc;
	$self->{codepage_tag} = 0;
	$self->{codepage_attr} = 0;
	my $tag = $self->get_tag();
	while ($tag == PI) {
		$rc = $self->pi();
		return undef unless (defined $rc);
		$tag = $self->get_tag();
	}
	$rc = $self->element($tag);
	return undef unless (defined $rc);
	$tag = $self->get_tag();
	if (defined $tag) {
		while ($tag == PI) {
			$rc = $self->pi();
			return undef unless (defined $rc);
			$tag = $self->get_tag();
		}
	}
	return 1;
}

sub pi {
	my $self = shift;
	my $attr = $self->get_attr();
	my $rc = $self->attribute($attr);
	return undef unless (defined $rc);
	my $target = $self->{attrs};
	$attr = $self->get_attr();
	my $data = '';
	while ($attr != _END) {
		$rc = $self->attribute($attr);
		return undef unless (defined $rc);
		$data .= $self->{attrv};
		$attr = $self->get_attr();
	}
	delete $self->{attrs};
	delete $self->{attrv};
	if ($self->{DocumentHandler}->can('processing_instruction')) {
		$self->{DocumentHandler}->processing_instruction( {		# fire
				Target		=> $target,
				Data		=> $data
		} );
	}
	return 1;
}

sub element {
	my $self = shift;
	my ($tag) = @_;

	return undef unless (defined $tag);
	my $token = $tag & TAG_MASK;
	my $name;
	if ($token == LITERAL) {
		my $idx = $self->getmb32();
		$name = $self->get_str_t($idx);
		return undef unless (defined $name);
	} else {
		$token += 256 * $self->{codepage_tag};
		if (	    defined $self->{App}
				and exists $self->{App}{TAG}{$token}) {
			$name = $self->{App}{TAG}{$token};
		} else {
			$name = "TAG-$token";
			$self->warning("$name unreferenced");
		}
	}
	my %attrs;
	if ($tag & HAS_ATTR) {
		my $attr = $self->get_attr();
		while ($attr != _END) {
			my $rc = $self->attribute($attr);
			return undef unless (defined $rc);
			$attrs{$self->{attrs}} = $self->{attrv}
					if (exists $self->{attrs});
			$attr = $self->get_attr();
		}
		delete $self->{attrs};
		delete $self->{attrv};
	}
	if ($self->{DocumentHandler}->can('start_element')) {
		$self->{DocumentHandler}->start_element( {				# fire
				Name		=> $name,
				Attributes	=> \%attrs
		} );
	}
	if ($tag & HAS_CHILD) {
		while ((my $child = $self->get_tag()) != _END) {
			my $rc = $self->content($child);
			return undef unless (defined $rc);
		}
	}
	if ($self->{DocumentHandler}->can('end_element')) {
		$self->{DocumentHandler}->end_element( {				# fire
				Name		=> $name
		} );
	}
	return 1;
}

sub content {
	my $self = shift;
	my ($tag) = @_;

	return undef unless (defined $tag);
	if      ($tag == ENTITY) {
		my $entcode = $self->getmb32();
		return undef unless (defined $entcode);
		$self->{DocumentHandler}->characters( {					# fire
				Data => chr $entcode
		} );
	} elsif ($tag == STR_I) {
		my $string = $self->get_str_i();
		return undef unless (defined $string);
		if (	    defined $self->{App}
				and exists $self->{App}{variable_subs} ) {
			$string =~ s/\$/\$\$/g;
		}
		$self->{DocumentHandler}->characters( {					# fire
				Data => $string
		} );
	} elsif ($tag == EXT_I_0) {
		my $string = $self->get_str_i();
		return undef unless (defined $string);
		if (	    defined $self->{App}
				and exists $self->{App}{variable_subs} ) {
			$self->{DocumentHandler}->characters( {				# fire
					Data => "\$($string:escape)"
			} );
		} else {
			$self->error("EXT_I_0 unexpected");
		}
	} elsif ($tag == EXT_I_1) {
		my $string = $self->get_str_i();
		return undef unless (defined $string);
		if (	    defined $self->{App}
				and exists $self->{App}{variable_subs} ) {
			$self->{DocumentHandler}->characters( {				# fire
				Data => "\$($string:unesc)"
			} );
		} else {
			$self->error("EXT_I_1 unexpected");
		}
	} elsif ($tag == EXT_I_2) {
		my $string = $self->get_str_i();
		return undef unless (defined $string);
		if (	    defined $self->{App}
				and exists $self->{App}{variable_subs} ) {
			$self->{DocumentHandler}->characters( {				# fire
				Data => "\$($string)"
			} );
		} else {
			$self->error("EXT_I_2 unexpected");
		}
	} elsif ($tag == PI) {
		my $rc = $self->pi();
		return undef unless (defined $rc);
	} elsif ($tag == EXT_T_0) {
		my $idx = $self->getmb32();
		my $string = $self->get_str_t($idx);
		return undef unless (defined $string);
		if (	    defined $self->{App}
				and exists $self->{App}{variable_subs} ) {
			$self->{DocumentHandler}->characters( {				# fire
					Data => "\$($string:escape)"
			} );
		} else {
			$self->error("EXT_T_0 unexpected");
		}
	} elsif ($tag == EXT_T_1) {
		my $idx = $self->getmb32();
		my $string = $self->get_str_t($idx);
		return undef unless (defined $string);
		if (	    defined $self->{App}
				and exists $self->{App}{variable_subs} ) {
			$self->{DocumentHandler}->characters( {				# fire
				Data => "\$($string:unesc)"
			} );
		} else {
			$self->error("EXT_T_1 unexpected");
		}
	} elsif ($tag == EXT_T_2) {
		my $idx = $self->getmb32();
		my $string = $self->get_str_t($idx);
		return undef unless (defined $string);
		if (	    defined $self->{App}
				and exists $self->{App}{variable_subs} ) {
			$self->{DocumentHandler}->characters( {				# fire
				Data => "\$($string)"
			} );
		} else {
			$self->error("EXT_T_2 unexpected");
		}
	} elsif ($tag == STR_T) {
		my $idx = $self->getmb32();
		my $string = $self->get_str_t($idx);
		return undef unless (defined $string);
		if (	    defined $self->{App}
				and exists $self->{App}{variable_subs} ) {
			$string =~ s/\$/\$\$/g;
		}
		$self->{DocumentHandler}->characters( {					# fire
				Data => $string
		} );
	} elsif ($tag == EXT_0) {
		$self->error("EXT_0 unexpected");
	} elsif ($tag == EXT_1) {
		$self->error("EXT_1 unexpected");
	} elsif ($tag == EXT_2) {
		$self->error("EXT_2 unexpected");
	} elsif ($tag == OPAQUE) {
		my $data = $self->get_opaque();
		return undef unless (defined $data);
		$self->error("OPAQUE unexpected");
	} else {
		my $rc = $self->element($tag);	# LITERAL and all TAG
		return undef unless (defined $rc);
	}
	return 1;
}

sub attribute {
	my $self = shift;
	my ($attr) = @_;

	return undef unless (defined $attr);
	if      ($attr == ENTITY) {		# ATTRV
		my $entcode = $self->getmb32();
		return undef unless (defined $entcode);
		$self->{attrv} .= chr $entcode;
	} elsif ($attr == STR_I) {		# ATTRV
		my $string = $self->get_str_i();
		return undef unless (defined $string);
		if (	    exists $self->{ATTRSTART}{validate}
				and $self->{ATTRSTART}{validate} eq 'vdata' ) {
			$string =~ s/\$/\$\$/g;
		}
		$self->{attrv} .= $string;
	} elsif ($attr == LITERAL) {	# ATTRS
		my $idx = $self->getmb32();
		my $string = $self->get_str_t($idx);
		return undef unless (defined $string);
		$self->{attrs} = $string;
		$self->{attrv} = '';
		$self->{ATTRSTART} = undef;
	} elsif ($attr == EXT_I_0) {	# ATTRV
		my $string = $self->get_str_i();
		return undef unless (defined $string);
		if (	    defined $self->{ATTRSTART}
				and $self->{ATTRSTART}{validate} eq 'vdata' ) {
			$self->{attrv} .= "\$($string:escape)";
		} else {
			$self->error("EXT_I_0 unexpected");
		}
	} elsif ($attr == EXT_I_1) {	# ATTRV
		my $string = $self->get_str_i();
		return undef unless (defined $string);
		if (	    defined $self->{ATTRSTART}
				and $self->{ATTRSTART}{validate} eq 'vdata' ) {
			$self->{attrv} .= "\$($string:unesc)";
		} else {
			$self->error("EXT_I_1 unexpected");
		}
	} elsif ($attr == EXT_I_2) {	# ATTRV
		my $string = $self->get_str_i();
		return undef unless (defined $string);
		if (	    defined $self->{ATTRSTART}
				and $self->{ATTRSTART}{validate} eq 'vdata' ) {
			$self->{attrv} .= "\$($string)";
		} else {
			$self->error("EXT_I_2 unexpected");
		}
	} elsif ($attr == EXT_T_0) {	# ATTRV
		my $idx = $self->getmb32();
		my $string = $self->get_str_t($idx);
		return undef unless (defined $string);
		if (	    defined $self->{ATTRSTART}
				and $self->{ATTRSTART}{validate} eq 'vdata' ) {
			$self->{attrv} .= "\$($string:escape)";
		} else {
			$self->error("EXT_T_0 unexpected");
		}
	} elsif ($attr == EXT_T_1) {	# ATTRV
		my $idx = $self->getmb32();
		my $string = $self->get_str_t($idx);
		return undef unless (defined $string);
		if (	    defined $self->{ATTRSTART}
				and $self->{ATTRSTART}{validate} eq 'vdata' ) {
			$self->{attrv} .= "\$($string:unesc)";
		} else {
			$self->error("EXT_T_1 unexpected");
		}
	} elsif ($attr == EXT_T_2) {	# ATTRV
		my $idx = $self->getmb32();
		my $string = $self->get_str_t($idx);
		return undef unless (defined $string);
		if (	    defined $self->{ATTRSTART}
				and $self->{ATTRSTART}{validate} eq 'vdata' ) {
			$self->{attrv} .= "\$($string)";
		} else {
			$self->error("EXT_T_2 unexpected");
		}
	} elsif ($attr == STR_T) {		# ATTRV
		my $idx = $self->getmb32();
		my $string = $self->get_str_t($idx);
		return undef unless (defined $string);
		if (	    exists $self->{ATTRSTART}{validate}
				and $self->{ATTRSTART}{validate} eq 'vdata' ) {
			$string =~ s/\$/\$\$/g;
		}
		$self->{attrv} .= $string;
	} elsif ($attr == EXT_0) {		# ATTRV
		$self->error("EXT_0 unexpected");
	} elsif ($attr == EXT_1) {		# ATTRV
		$self->error("EXT_1 unexpected");
	} elsif ($attr == EXT_2) {		# ATTRV
		$self->error("EXT_2 unexpected");
	} elsif ($attr == OPAQUE) {		# ATTRV
		my $data = $self->get_opaque();
		return undef unless (defined $data);
		if (	    exists $self->{ATTRSTART}{encoding}
				and $self->{ATTRSTART}{encoding} eq 'iso-8601' ) {
			foreach (split //,$data) {
				$self->{attrv} .=  sprintf("%02X",ord $_);
			}
		} else {
			$self->error("OPAQUE unexpected");
		}
	} else {
		my $token = $attr; # & ATTR_MASK;
		$token += 256 * $self->{codepage_attr};
		if ($attr & 0x80) {
			if (	    defined $self->{App}
					and exists $self->{App}{ATTRVALUE}{$token}) {
				$self->{attrv} .= $self->{App}{ATTRVALUE}{$token};
			} else {
				$self->{attrv} .=  "ATTRV-$token";
				$self->warning("ATTRV-$token unreferenced");
			}
		} else {
			$self->{attrv} = '';
			$self->{ATTRSTART} = undef;
			if (	    defined $self->{App}
					and exists $self->{App}{ATTRSTART}{$token} ) {
				$self->{ATTRSTART} = $self->{App}{ATTRSTART}{$token};
				$self->{attrs} = $self->{ATTRSTART}{name};
				$self->{attrv} = $self->{ATTRSTART}{value}
						if (exists $self->{ATTRSTART}{value});
			} else {
				$self->{attrs} = "ATTRS-$token";
				$self->warning("ATTRS-$token unreferenced");
			}
		}
	}
	return 1;
}

sub get_tag {
	my $self = shift;
	my $ch = $self->{io_handle}->getc();
	return undef unless (defined $ch);
	my $tag = ord $ch;
	if ($tag == SWITCH_PAGE) {
		$ch = $self->{io_handle}->getc();
		return undef unless (defined $ch);
		$self->{codepage_tag} = ord $ch;
		$ch = $self->{io_handle}->getc();
		return undef unless (defined $ch);
		$tag = ord $ch;
	}
	return $tag;
}

sub get_attr {
	my $self = shift;
	my $ch = $self->{io_handle}->getc();
	return undef unless (defined $ch);
	my $attr = ord $ch;
	if ($attr == SWITCH_PAGE) {
		$ch = $self->{io_handle}->getc();
		return undef unless (defined $ch);
		$self->{codepage_attr} = ord $ch;
		$ch = $self->{io_handle}->getc();
		return undef unless (defined $ch);
		$attr = ord $ch;
	}
	return $attr;
}

sub get_str_i {
	my $self = shift;
	my $str = '';
	my $ch = $self->{io_handle}->getc();
	return undef unless (defined $ch);
	while (ord $ch != 0) {
		$str .= $ch;
		$ch = $self->{io_handle}->getc();
		return undef unless (defined $ch);
	}
	return $str;
}

sub get_opaque {
	my $self = shift;
	my $data;
	my $len = $self->getmb32();
	return undef unless (defined $len);
	$self->{io_handle}->read($data,$len);
	return $data;
}

sub warning {
	my $self = shift;
	my ($msg) = @_;
	my $pos = $self->{io_handle}->tell();
	if ($self->{ErrorHandler}->can('warning')) {
		$self->{ErrorHandler}->warning( {						# fire
				Message			=> $msg,
				PublicId		=> $self->{PublicId},
				ColumnNumber	=> $pos,
				LineNumber		=> 1,
				BytePosition	=> $pos
		} );
	} else {
		warn __PACKAGE__,": Warning: $msg\n\tat position $pos\n";
	}
}

sub error {
	my $self = shift;
	my ($msg) = @_;
	my $pos = $self->{io_handle}->tell();
	if ($self->{ErrorHandler}->can('error')) {
		$self->{ErrorHandler}->error( {							# fire
				Message			=> $msg,
				PublicId		=> $self->{PublicId},
				ColumnNumber	=> $pos,
				LineNumber		=> 1,
				BytePosition	=> $pos
		} );
	} else {
		warn __PACKAGE__,": Error: $msg\n\tat position $pos\n";
	}
}

1;

__END__

=head1 NAME

WAP::SAXDriver::wbxml - SAX parser for WBXML file

=head1 SYNOPSIS

 use WAP::SAXDriver::wbxml;

 $parser = WAP::SAXDriver::wbxml->new( [OPTIONS] );
 $result = $parser->parse( [OPTIONS] );

=head1 DESCRIPTION

C<WAP::SAXDriver::wbxml> is a PerlSAX parser.
This man page summarizes the specific options, handlers, and
properties supported by C<WAP::SAXDriver::wbxml>; please refer to the
PerlSAX standard in `C<PerlSAX.pod>' for general usage information.

A WBXML file is the binarized form of XML file according the specification :

 WAP - Wireless Application Protocol /
 Binary XML Content Format Specification /
 Version 1.3 WBXML (15th May 2000 Approved)

This module could be parametrized by the file C<WAP::SAXDriver::wbrules.pl>
what contains all specific values used by WAP applications.

This module needs IO::File, IO::String and I18N::Charset modules.

=head1 METHODS

=over 4

=item new

Creates a new parser object.  Default options for parsing, described
below, are passed as key-value pairs or as a single hash.  Options may
be changed directly in the parser object unless stated otherwise.
Options passed to `C<parse()>' override the default options in the
parser object for the duration of the parse.

=item parse

Parses a document.  Options, described below, are passed as key-value
pairs or as a single hash.  Options passed to `C<parse()>' override
default options in the parser object.

=item location

Returns the location as a hash:

  BytePosition    The current byte position of the parse.
  ColumnNumber    The column number of the parse, equals to BytePosition.
  LineNumber      The line number of the parse, always equals to 1.
  PublicId        A string containing the public identifier, or undef
                  if none is available.

=back

=head1 OPTIONS

The following options are supported by C<WAP::SAXDriver::wbxml> :

 Handler              default handler to receive events
 DocumentHandler      handler to receive document events
 DTDHandler           handler to receive DTD events
 ErrorHandler         handler to receive error events
 Source               hash containing the input source for parsing
 UseOnlyDefaultRules  boolean, if true the file wbrules.pl is not loaded

If no handlers are provided then all events will be silently ignored,
except for `C<fatal_error()>' which will cause a `C<die()>' to be
called after calling `C<end_document()>'.

The `C<Source>' hash may contain the following parameters:

 ByteStream       The raw byte stream (file handle) containing the
                  document.
 String           A string containing the document.
 Encoding         A string describing the character encoding.

If more than one of `C<ByteStream>', or `C<String>',
then preference is given first to `C<ByteStream>', then `C<String>'.

=head1 HANDLERS

The following handlers and properties are supported by
C<WAP::SAXDriver::wbxml> :

=head2 DocumentHandler methods

=over 4

=item start_document

Receive notification of the beginning of a document.

No properties defined.

=item end_document

Receive notification of the end of a document.

No properties defined.

=item start_element

Receive notification of the beginning of an element.

 Name             The element type name.
 Attributes       A hash containing the attributes attached to the
                  element, if any.

The `C<Attributes>' hash contains only string values.

=item end_element

Receive notification of the end of an element.

 Name             The element type name.

=item characters

Receive notification of character data.

 Data             The characters from the XML document.

=item processing_instruction

Receive notification of a processing instruction.

 Target           The processing instruction target.
 Data             The processing instruction data, if any.

=back

=head2 DTDHandler methods

=over 4

=item xml_decl

Receive notification of an XML declaration event.

 Version          The XML version, always 1.0.
 Encoding         The encoding string, if any.
 Standalone       undefined.
 VersionWBXML     The version used for the binarization.
 PublicId         The document's public identifier.

=back

=head2 ErrorHandler methods

=over 4

=item warning

Receive notification of an warning event.

  Message         The detailed explanation.
  BytePosition    The current byte position of the parse.
  ColumnNumber    The column number of the parse, equals to BytePosition.
  LineNumber      The line number of the parse, always equals to 1.
  PublicId        A string containing the public identifier, or undef
                  if none is available.

=item error

Receive notification of an error event.

  Message         The detailed explanation.
  BytePosition    The current byte position of the parse.
  ColumnNumber    The column number of the parse, equals to BytePosition.
  LineNumber      The line number of the parse, always equals to 1.
  PublicId        A string containing the public identifier, or undef
                  if none is available.

=item fatal_error

Receive notification of an fatal error event.

  BytePosition    The current byte position of the parse.
  ColumnNumber    The column number of the parse, equals to BytePosition.
  LineNumber      The line number of the parse, always equals to 1.
  PublicId        A string containing the public identifier, or undef
                  if none is available.

=back

=head1 COPYRIGHT

(c) 2002 Francois PERRAD, France. All rights reserved.

This program is distributed under the terms of the Artistic Licence.

The WAP Specifications are copyrighted by the Wireless Application Protocol Forum Ltd.
See E<lt>http://www.wapforum.org/what/copyright.htmE<gt>.

=head1 AUTHOR

Francois PERRAD, E<lt>perrad@besancon.sema.slb.comE<gt>

=head1 SEE ALSO

perl(1), PerlSAX.pod(3), WAP::wbxml

 Extensible Markup Language (XML) <http://www.w3c.org/XML/>
 Binary XML Content Format (WBXML) <http://www.wapforum.org/>
 Simple API for XML (SAX) <http://www.saxproject.org/>

=cut
