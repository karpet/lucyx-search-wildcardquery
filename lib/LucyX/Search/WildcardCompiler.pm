package LucyX::Search::WildcardCompiler;
use strict;
use warnings;
use base qw( Lucy::Search::Compiler );
use Carp;
use Lucy::Search::ORQuery;
use Lucy::Search::TermQuery;
use Data::Dump qw( dump );

our $VERSION = '0.04';

my $DEBUG = $ENV{LUCYX_DEBUG} || 0;

# inside out vars
my ( %searcher, %ORCompiler, %ORQuery, %subordinate );

sub DESTROY {
    my $self = shift;
    delete $ORQuery{$$self};
    delete $ORCompiler{$$self};
    delete $searcher{$$self};
    delete $subordinate{$$self};
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
    my $class    = shift;
    my %args     = @_;
    my $searcher = $args{searcher} || $args{searchable};
    if ( !$searcher ) {
        croak "searcher required";
    }

    my $subordinate = delete $args{subordinate};
    my $self        = $class->SUPER::new(%args);
    $searcher{$$self}    = $searcher;
    $subordinate{$$self} = $subordinate;

    return $self;
}

=head2 make_matcher( I<args> )

Returns a LucyX::Search::WildcardScorer object.

=cut

sub make_matcher {
    my ( $self, %args ) = @_;

    # Retrieve low-level components
    my $seg_reader = $args{reader};
    my $lex_reader = $seg_reader->obtain("Lucy::Index::LexiconReader");
    my $parent     = $self->get_parent;
    my $term       = $parent->get_term;
    my $regex      = $parent->get_regex;
    my $suffix     = $parent->get_suffix;
    my $field      = $parent->get_field;
    my $prefix     = $parent->get_prefix;
    my $lexicon    = $lex_reader->lexicon( field => $field );
    return unless $lexicon;

    # shortcut to avoid looking at every term
    $lexicon->seek( defined $prefix ? $prefix : '' );

    # Accumulate TermQuery objects
    my @terms;
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

        unless ( $lex_term =~ $regex ) {
            last unless $lexicon->next;
            next;
        }

        push @terms,
            Lucy::Search::TermQuery->new(
            term  => $lex_term,
            field => $field,
            );

        $parent->add_lex_term($lex_term);

        last unless $lexicon->next;
    }

    return if !@terms;

    $DEBUG and warn dump \@terms;

    my $or_query = Lucy::Search::ORQuery->new( children => \@terms, );
    $ORQuery{$$self} = $or_query;
    my $or_compiler
        = $or_query->make_compiler( searcher => $searcher{$$self} );
    $ORCompiler{$$self} = $or_compiler;
    return $or_compiler->make_matcher(%args);
}

=head2 get_searcher

Returns the Searcher passed in new().

=cut

sub get_searcher {
    my $self = shift;
    return $searcher{$$self};
}

=head2 get_weight

Delegates to ORCompiler child.

=cut

sub get_weight {
    my $self = shift;
    return $ORCompiler{$$self}->get_weight();
}

=head2 get_similarity

Delegates to ORCompiler child.

=cut

sub get_similarity {
    my $self = shift;
    return $ORCompiler{$$self}->get_similarity();
}

=head2 normalize

Delegates to ORCompiler child.

=cut

sub normalize {
    my $self = shift;
    return $ORCompiler{$$self}->normalize();
}

=head2 sum_of_squared_weights

Delegates to ORCompiler child.

=cut

sub sum_of_squared_weights {
    my $self = shift;
    return $ORCompiler{$$self}->sum_of_squared_weights();
}

=head2 highlight_spans

Delegates to ORCompiler child.

=cut

sub highlight_spans {
    my $self = shift;
    return $ORCompiler{$$self}->highlight_spans(@_);
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
