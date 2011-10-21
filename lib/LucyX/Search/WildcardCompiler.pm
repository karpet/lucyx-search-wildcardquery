package LucyX::Search::WildcardCompiler;
use strict;
use warnings;
use base qw( Lucy::Search::Compiler );
use Carp;
use LucyX::Search::WildcardScorer;
use Lucy::Search::Span;
use Data::Dump qw( dump );

our $VERSION = '0.03';

my $DEBUG = $ENV{LUCYX_DEBUG} || 0;

# inside out vars
my ( %include, %searchable, %idf, %raw_impact, %doc_freq, %query_norm_factor,
    %normalized_impact, %term_freq, );

sub DESTROY {
    my $self = shift;
    delete $include{$$self};
    delete $raw_impact{$$self};
    delete $query_norm_factor{$$self};
    delete $searchable{$$self};
    delete $normalized_impact{$$self};
    delete $idf{$$self};
    delete $doc_freq{$$self};
    delete $term_freq{$$self};
    $self->SUPER::DESTROY;
}

=head1 NAME

LucyX::Search::WildcardCompiler - Lucy query extension

=head1 SYNOPSIS

    # see Lucy::Search::Compiler

=head1 METHODS

This class isa Lucy::Search::Compiler subclass. Only new
or overridden methods are documented .

=cut

=head2 new( I<args> )

Returns a new Compiler object.

=cut

sub new {
    my $class      = shift;
    my %args       = @_;
    my $include    = delete $args{include} || 0;
    my $searchable = $args{searchable} || $args{searcher};
    if ( !$searchable ) {
        croak "searcher required";
    }
    my $self = $class->SUPER::new(%args);
    $include{$$self}    = $include;
    $searchable{$$self} = $searchable;
    return $self;
}

=head2 make_matcher( I<args> )

Returns a Search::Query::Dialect::Lucy::Scorer object.

=cut

sub make_matcher {
    my ( $self, %args ) = @_;

    my $seg_reader = $args{reader};
    my $searchable = $searchable{$$self};

    # Retrieve low-level components LexiconReader and PostingListReader.
    my $lex_reader   = $seg_reader->obtain("Lucy::Index::LexiconReader");
    my $plist_reader = $seg_reader->obtain("Lucy::Index::PostingListReader");

    # Acquire a Lexicon and seek it to our query string.
    my $parent  = $self->get_parent;
    my $term    = $parent->get_term;
    my $regex   = $parent->get_regex;
    my $suffix  = $parent->get_suffix;
    my $field   = $parent->get_field;
    my $prefix  = $parent->get_prefix;
    my $lexicon = $lex_reader->lexicon( field => $field );
    return unless $lexicon;

    # Retrieve the correct Similarity for the Query's field.
    my $sim = $args{similarity} || $searchable->get_schema->fetch_sim($field);

    $lexicon->seek( defined $prefix ? $prefix : '' );

    # Accumulate PostingLists for each matching term.
    my @posting_lists;
    my $include = $include{$$self};
    while ( defined( my $lex_term = $lexicon->get_term ) ) {

        $DEBUG and warn sprintf(
            "\n lex_term='%s'\n prefix=%s\n suffix=%s\n regex=%s\n",
            ( defined $lex_term ? $lex_term : '[undef]' ),
            ( defined $prefix   ? $prefix   : '[undef]' ),
            ( defined $suffix   ? $suffix   : '[undef]' ),
            ( defined $regex    ? $regex    : '[undef]' )
        );

        # weed out non-matchers early.
        if ( defined $suffix and index( $lex_term, $suffix ) < 0 ) {
            last unless $lexicon->next;
            next;
        }
        last if defined $prefix and index( $lex_term, $prefix ) != 0;

        $DEBUG and carp "$term field:$field: term>$lex_term<";

        if ($include) {
            unless ( $lex_term =~ $regex ) {
                last unless $lexicon->next;
                next;
            }
        }
        else {
            if ( $lex_term =~ $regex ) {
                last unless $lexicon->next;
                next;
            }
        }
        my $posting_list = $plist_reader->posting_list(
            field => $field,
            term  => $lex_term,
        );

        $DEBUG and carp "check posting_list";
        if ($posting_list) {
            push @posting_lists, $posting_list;
            $parent->add_lex_term($lex_term);
        }
        last unless $lexicon->next;
    }
    return unless @posting_lists;

    $doc_freq{$$self} = scalar(@posting_lists);

    $DEBUG and carp dump \@posting_lists;

    # Calculate and store the IDF
    my $max_doc = $searchable->doc_max;
    my $idf     = $idf{$$self}
        = $max_doc
        ? $searchable->get_schema->fetch_type($field)->get_boost
        + log( $max_doc / ( 1 + $doc_freq{$$self} ) )
        : $searchable->get_schema->fetch_type($field)->get_boost;

    $raw_impact{$$self} = $idf * $parent->get_boost;

    $DEBUG and carp "raw_impact{$$self}= $raw_impact{$$self}";

    # make final preparations
    $self->_perform_query_normalization($searchable);

    return LucyX::Search::WildcardScorer->new(
        posting_lists => \@posting_lists,
        compiler      => $self,
    );
}

=head2 get_searchable

Returns the Searchable object for this Compiler.

=cut

sub get_searchable {
    my $self = shift;
    return $searchable{$$self};
}

=head2 get_doc_freq

Returns the document frequency for this Compiler.

=cut

sub get_doc_freq {
    my $self = shift;
    return $doc_freq{$$self};
}

sub _perform_query_normalization {

    # copied from Lucy::Search::Weight originally
    my ( $self, $searcher ) = @_;
    my $sim    = $self->get_similarity;
    my $factor = $self->sum_of_squared_weights;    # factor = ( tf_q * idf_t )
    $factor = $sim->query_norm($factor);           # factor /= norm_q
    $self->normalize($factor);                     # impact *= factor

    #carp "normalize factor=$factor";
}

=head2 apply_norm_factor( I<factor> )

Overrides base class. Currently just passes I<factor> on to parent method.

=cut

sub apply_norm_factor {

    # pass-through for now
    my ( $self, $factor ) = @_;
    $self->SUPER::apply_norm_factor($factor);
}

=head2 get_boost

Returns the boost for the parent Query object.

=cut

sub get_boost { shift->get_parent->get_boost }

=head2 sum_of_squared_weights

Returns imact of term on score.

=cut

sub sum_of_squared_weights {

    # pass-through for now
    my $self = shift;
    return exists $raw_impact{$$self} ? $raw_impact{$$self}**2 : '1.0';
}

=head2 normalize()

Affects the score of the term. See Lucy::Search::Compiler.

=cut

sub normalize {    # copied from TermQuery
    my ( $self, $query_norm_factor ) = @_;
    $query_norm_factor{$$self} = $query_norm_factor || 1;

    # Multiply raw impact by ( tf_q * idf_q / norm_q )
    #
    # Note: factoring in IDF a second time is correct.  See formula.
    #warn "raw_impact=$raw_impact{$$self}";
    #warn "idf=$idf{$$self}";
    #warn "query_norm_factor=$query_norm_factor";

    $normalized_impact{$$self}
        = $raw_impact{$$self} * $idf{$$self} * $query_norm_factor;

    #carp "normalized_impact{$$self} = $normalized_impact{$$self}";
    return $normalized_impact{$$self};
}

=head2 highlight_spans( I<args> )

See documentation in Lucy::Search::Query.

Returns arrayref of Lucy::Search::Span objects.

=cut

sub highlight_spans {
    my ( $self, %params ) = @_;

    # call super method immediately just to test %params.
    # it will always return empty array ref, which we can use.
    my $spans  = $self->SUPER::highlight_spans(%params);
    my $parent = $self->get_parent;
    my $term   = $parent->get_term;

    return $spans unless defined $term and length $term;
    return $spans unless $parent->get_field eq $params{field};

    my $lex_terms = $parent->get_lex_terms;
    for my $t (@$lex_terms) {

        my $term_vec = $params{doc_vec}
            ->term_vector( field => $params{field}, term => $t );
        next unless $term_vec;

        my $starts = $term_vec->get_start_offsets->to_arrayref;
        my $ends   = $term_vec->get_end_offsets->to_arrayref;
        my $i      = 0;
        for my $s (@$starts) {
            my $len = $ends->[ $i++ ] - $s;
            push @$spans,
                Lucy::Search::Span->new(
                offset => $s,
                length => $len,
                weight => $parent->get_boost,
                );
        }

    }

    return $spans;
}

1;

__END__

=head1 AUTHOR

Peter Karman, C<< <karman at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-lucyx-search-wildcardquery at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=LucyX-Search-WildcardQuery>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc LucyX::Search::WildcardQuery


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=LucyX-Search-WildcardQuery>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/LucyX-Search-WildcardQuery>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/LucyX-Search-WildcardQuery>

=item * Search CPAN

L<http://search.cpan.org/dist/LucyX-Search-WildcardQuery/>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2011 Peter Karman.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut
