package Mongoose::Cursor;

use Moose;
use MongoDB;
extends 'MongoDB::Cursor';

has '_class' => ( is=>'rw', isa=>'Str', required=>1 );
has '_collection_name' => ( is=>'rw', isa=>'Str', required=>1 );

around 'next' => sub {
    my ($orig,$self, @args)=@_;
    my $doc = $self->$orig(@args);
    return unless defined $doc;
    my $coll_name = $self->_collection_name; 
    my $class = $self->_class;
    #eval "require " . $self->_class;
    return $class->expand( $doc );
};

around 'all' => sub {
    my ($orig,$self, @args)=@_;
    my @docs = $self->$orig(@args);

    return unless scalar @docs > 0;

    my $coll_name = $self->_collection_name; 
    my $class = $self->_class;

    return map { $class->expand( $_ ) } @docs;
};

sub each(&) {
    my $self = shift;
    my $func = shift;
    while( my $r = $self->next ) {
        last unless defined $func->( $r ) 
    }
}

sub hash_on {
    my $self = shift;
    my $key = shift;
    my %hash;
    while( my $r = $self->next ) {
        $hash{ $r->{$key} } = $r unless exists $hash{ $r->{$key} };
    }
    return %hash;
}

sub hash_array {
    my $self = shift;
    my $key = shift;
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

Wraps L<MongoDB::Cursor>'s C<next> and C<all>methods,
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

=head2 all

Wrapper around MongoDB's C<all>. 

=head2 hash_on

Returns all data as a HASH indexed by the key sent as first argument. 
Rows with duplicate keys are ignored.

    %tracks = $cd->tracks->find->hash_on('track_name');

=head2 hash_array

Returns all data as a HASH indexed by the key sent as first argument. 
Hash values are ARRAYREFs with 1 or more rows.

    %tracks = $cd->tracks->find->hash_array('track_name');

=cut 

1;
