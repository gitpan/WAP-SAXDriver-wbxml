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
    },
    'PM'            => {
                        'wbxml.pm'      => '$(INST_LIBDIR)/wbxml.pm',
                        'wbrules.pl'    => '$(INST_LIBDIR)/wbrules.pl',
    },
    'EXE_FILES'     => ['xmld'],
    'AUTHOR'        => "Francois PERRAD (perrad\@besancon.sema.slb.com)",
    'dist'          => {
                        'COMPRESS'      => 'gzip',
                        'SUFFIX'        => '.gz',
    },
);
