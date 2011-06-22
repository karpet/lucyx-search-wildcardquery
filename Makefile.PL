use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'LucyX::Search::WildcardQuery',
    AUTHOR              => q{Peter Karman <karman@cpan.org>},
    VERSION_FROM        => 'lib/LucyX/Search/WildcardQuery.pm',
    ABSTRACT_FROM       => 'lib/LucyX/Search/WildcardQuery.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'LucyX-Search-WildcardQuery-*' },
);
