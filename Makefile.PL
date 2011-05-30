use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'          => 'WAP::SAXDriver::wbxml',
    'VERSION_FROM'  => 'lib/WAP/SAXDriver/wbxml.pm', # finds $VERSION
    'ABSTRACT'      => 'SAX2 parser for WBXML file used by Wireless Application Protocol',
    'PREREQ_PM'     => {
                        'IO::String'        => 0,
                        'I18N::Charset'     => '1.15',
                        'WAP::wbxml'        => '1.13',
                        'XML::SAX'          => '0.12',
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

sub MY::top_targets {
    package MY;
    my $script = shift->SUPER::top_targets(@_);
    $script =~ s/pure_all :: (.*)$/pure_all :: $1 wap_rules/m;
    $script .= <<"WAP";

wap_rules :
\t\$(MKPATH) ./lib/WAP/SAXDriver/wbxml
\t\$(PERL) ./bin/mkwbrules -p \$(DESTINSTALLSITELIB)/WAP/wbxml/wap.wbrules.xml
\t\$(CP) ./wbrules2.pl ./lib/WAP/SAXDriver/wbxml/wap.wbrules2.pl
\t\$(RM_F) ./wbrules2.pl
\t\$(PERL) ./bin/mkwbrules -p \$(DESTINSTALLSITELIB)/WAP/wbxml/wv.wbrules.xml
\t\$(CP) ./wbrules2.pl ./lib/WAP/SAXDriver/wbxml/wv.wbrules2.pl
\t\$(RM_F) ./wbrules2.pl
\t\$(PERL) ./bin/mkwbrules -p \$(DESTINSTALLSITELIB)/WAP/wbxml/syncml.wbrules.xml
\t\$(CP) ./wbrules2.pl ./lib/WAP/SAXDriver/wbxml/syncml.wbrules2.pl
\t\$(RM_F) ./wbrules2.pl
\t\$(PERL) ./bin/mkwbrules -p \$(DESTINSTALLSITELIB)/WAP/wbxml/activesync.wbrules.xml
\t\$(CP) ./wbrules2.pl ./lib/WAP/SAXDriver/wbxml/activesync.wbrules2.pl
\t\$(RM_F) ./wbrules2.pl

WAP

    return $script;
}
