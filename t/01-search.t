#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Data::Dump qw( dump );
use File::Temp qw( tempdir );
my $invindex = tempdir( CLEANUP => 1 );

use Lucy::Plan::Schema;
use Lucy::Plan::FullTextType;
use Lucy::Analysis::PolyAnalyzer;
use Lucy::Index::Indexer;
use Lucy::Search::IndexSearcher;
use Lucy::Search::QueryParser;
my $schema   = Lucy::Plan::Schema->new;
my $analyzer = Lucy::Analysis::PolyAnalyzer->new( language => 'en', );
my $fulltext = Lucy::Plan::FullTextType->new(
    analyzer => $analyzer,
    sortable => 1,
);
$schema->spec_field( name => 'title',  type => $fulltext );
$schema->spec_field( name => 'color',  type => $fulltext );
$schema->spec_field( name => 'date',   type => $fulltext );
$schema->spec_field( name => 'option', type => $fulltext );

my $indexer = Lucy::Index::Indexer->new(
    index    => $invindex,
    schema   => $schema,
    create   => 1,
    truncate => 1,
);

my %docs = (
    'doc1' => {
        title  => 'i am doc1',
        color  => 'red blue orange',
        date   => '20100329',
        option => 'a',
    },
    'doc2' => {
        title  => 'i am doc2',
        color  => 'green yellow purple',
        date   => '20100301',
        option => 'b',
    },
    'doc3' => {
        title  => 'i am doc3',
        color  => 'brown black white',
        date   => '19720329',
        option => '',
    },
    'doc4' => {
        title  => 'i am doc4',
        color  => 'white',
        date   => '20100510',
        option => 'c',
    },
    'doc5' => {
        title  => 'unlike the others',
        color  => 'teal',
        date   => '19000101',
        option => 'd',
    },
);

# set up the index
for my $doc ( keys %docs ) {
    $indexer->add_doc( $docs{$doc} );
}

$indexer->commit;

my $searcher = Lucy::Search::IndexSearcher->new( index => $invindex, );

# search
my %queries = (
    'color:re*'                   => 1,
    'color:re?'                   => 1,
    'color:br?wn'                 => 1,
    'color:*n'                    => 2,
    'NOT option:?*'               => 1,
    '*oc*'                        => 4,
);

for my $str ( sort keys %queries ) {
    my $query = make_query($str);

    my $hits_expected = $queries{$str};
    if ( ref $hits_expected ) {
        $query->debug(1);
        $hits_expected = $hits_expected->[0];
    }

    #diag($query);
    my $hits = $searcher->hits(
        query      => $query,
        offset     => 0,
        num_wanted => 5,        # more than we have
    );

    is( $hits->total_hits, $hits_expected, "$str = $hits_expected" );

    if ( $hits->total_hits != $hits_expected ) {
        diag( dump $query->dump );
    }
}

# allow for adding new queries without adjusting test count
done_testing( scalar( keys %queries ) + 9 );

sub make_query {
    my $str = shift;

}
