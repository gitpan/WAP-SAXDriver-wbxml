use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'          => 'WAP::SAXDriver::wbxml',
    'VERSION_FROM'  => 'wbxml.pm', # finds $VERSION
    'ABSTRACT'      => 'SAX parser for WBXML file used by Wireless Application Protocol',
    'PREREQ_PM'     => {
                        'IO::File'      => 0,
                        'IO::String'    => 0,
                        'I18N::Charset' => '1.15',
                        'XML::SAX::Base'=> 0,
                        'WAP::wbxml'    => '1.06',
    },
    'PM'            => {
                        'wbxml.pm'      => '$(INST_LIBDIR)/wbxml.pm',
                        'wbrules.pl'    => '$(INST_LIBDIR)/wbrules.pl',
    },
    'EXE_FILES'     => ['wbxmld.pl'],
    'AUTHOR'        => "Francois PERRAD (francois.perrad\@gadz.org)",
    'dist'          => {
                        'COMPRESS'      => 'gzip',
                        'SUFFIX'        => '.gz',
    },
);
