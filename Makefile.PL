use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'          => 'WAP::SAXDriver::wbxml',
    'VERSION_FROM'  => 'lib/WAP/SAXDriver/wbxml.pm', # finds $VERSION
    'ABSTRACT'      => 'SAX2 parser for WBXML file used by Wireless Application Protocol',
    'PREREQ_PM'     => {
                        'IO::File'          => 0,
                        'IO::String'        => 0,
                        'I18N::Charset'     => '1.15',
                        'XML::SAX::Base'    => '1.00',
                        'XML::SAX::Writer'  => '0.44',
    },
    'EXE_FILES'     => [
                        'bin/wbxmld', 
                        'bin/syncmld', 
                        'bin/mkwbrules',
    ],
    'AUTHOR'        => "Francois PERRAD (francois.perrad\@gadz.org)",
    'dist'          => {
                        'COMPRESS'      => 'gzip',
                        'SUFFIX'        => '.gz',
    },
);
