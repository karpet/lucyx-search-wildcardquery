package LucyX::Search::NOTWildcardQuery;
use strict;
use warnings;
use base qw( LucyX::Search::WildcardQuery );
use Carp;

our $VERSION = '0.01';

=head1 NAME

LucyX::Search::NOTWildcardQuery - Lucy query extension

=head1 SYNOPSIS


 my $query = LucyX::Search::NOTWildcardQuery->new(
    term    => 'green*',
    field   => 'color',
 );
 my $hits = $searcher->hits( query => $query );
 
=head1 DESCRIPTION

If a WildcardQuery is equivalent to this:

 $term =~ m/$query/

then a NOTWildcardQuery is equivalent to this:

 $term !~ m/$query/

=head1 METHODS

This class isa LucyX::Search::WildcardQuery subclass.
Only new or overridden methods are documented.

=head2 make_compiler

Returns a LucyX::Search::WildcardCompiler object.

=cut

sub make_compiler {
    my $self = shift;
    return LucyX::Search::WildcardCompiler->new(
        @_,
        parent  => $self,
        include => 0,
    );
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
