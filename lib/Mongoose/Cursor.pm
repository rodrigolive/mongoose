package Mongoose::Cursor;

use Moose;
extends 'MongoDB::Cursor';

has _class           => ( is=>'rw', isa=>'Str', required=>1 );
has _collection_name => ( is=>'rw', isa=>'Str', required=>1 );

around 'next' => sub {
    my ($orig, $self) = (shift, shift);
    my $doc = $self->$orig(@_) || return;
    $self->_class->expand( $doc );
};

for my $arr_method (qw/ all batch /) {
    around $arr_method => sub {
        my ($orig, $self) = (shift, shift);
        map { $self->_class->expand( $_ ) } $self->$orig(@_);
    };
}

# Dumb re-implementation of deprecated count() method
sub count {
    my $self = shift;
    $self->_class->count($self->_query->filter);
}

sub each(&) {
    my ( $self, $cb ) = @_;
    while( my $r = $self->next ) { last unless defined $cb->($r) }
}

sub hash_on {
    my ($self, $key) = @_;

    my %hash;
    while( my $r = $self->next ) {
        $hash{ $r->{$key} } = $r unless exists $hash{ $r->{$key} };
    }
    return %hash;
}

sub hash_array {
    my ($self, $key) = @_;

    my %hash;
    while( my $r = $self->next ) {
        push @{ $hash{ $r->{$key} } }, $r;
    }
    return %hash;
}

=head1 NAME

Mongoose::Cursor - a Mongoose wrapper for MongoDB::Cursor

=head1 DESCRIPTION

Extends L<Mongoose::Cursor>.

Wraps L<MongoDB::Cursor>'s C<next>, C<all> and C<batch> methods,
so that it expands a document into a class.

=head1 METHODS

For your convenience:

=head2 each

Iterates over a cursor, calling your sub.

    Person->find->each( sub {
        my $obj = shift;

        # do stuff

        # return undef to break out
        return undef if $done;
    });

=head2 hash_on

Returns all data as a HASH indexed by the key sent as first argument.
Rows with duplicate keys are ignored.

    %tracks = $cd->tracks->find->hash_on('track_name');

=head2 hash_array

Returns all data as a HASH indexed by the key sent as first argument.
Hash values are ARRAYREFs with 1 or more rows.

    %tracks = $cd->tracks->find->hash_array('track_name');

=cut

__PACKAGE__->meta->make_immutable();
