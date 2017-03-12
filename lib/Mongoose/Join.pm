package Mongoose::Join;

use Moose;
use Moose::Util::TypeConstraints;
use Moose::Meta::TypeConstraint::Parameterizable;
use Moose::Meta::TypeConstraint::Registry;
use Tie::IxHash;

my $API_V1 = Mongoose->_mongodb_v1;

my $REGISTRY = Moose::Meta::TypeConstraint::Registry->new;
$REGISTRY->add_type_constraint(
    Moose::Meta::TypeConstraint::Parameterizable->new(
        name                 => 'Mongoose::Join',
        package_defined_in   => __PACKAGE__,
        parent               => find_type_constraint('Item'),
        constraint           => sub { die 'constrained' },
        constraint_generator => sub {
            my $type_parameter = shift;
            sub { return {} };
        }
    )
);

Moose::Util::TypeConstraints::add_parameterizable_type( $REGISTRY->get_type_constraint('Mongoose::Join') );

has 'class'                 => ( is => 'rw', isa => 'Str' );
has 'field'                 => ( is => 'rw', isa => 'Str' );
has 'with_class'            => ( is => 'rw', isa => 'Str' );
has '_with_collection_name' => ( is => 'rw', isa => 'Str' );
has 'parent'                => ( is => 'rw', isa => 'MongoDB::OID' );

# once the object is expanded, it has children too
has 'children'              => ( is => 'rw', isa => 'ArrayRef', default => sub{[]} );

# before being saved, objects are stored in this buffer
has 'buffer' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

# deleting happens at a later moment, meanwhile delete candidates are here
has 'delete_buffer' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

use Scalar::Util qw/refaddr/;

sub add {
    my ( $self, @objs ) = @_;
    for my $obj (@objs) {
        $self->buffer->{ refaddr $obj } = $obj;
    }
    @objs;
}

sub remove {
    my ( $self, @objs ) = @_;

    # if the collection is live, remove from memory
    if( my $buffer = $self->buffer ) {
        for my $obj (@objs) {
            next unless defined $obj;
            delete $buffer->{ refaddr $obj };
        }
    }

    # children get cleaned too
    if( defined ( my $children = $self->children ) ) {
        for my $obj (@objs) {
            my $id = $obj->_id;
            next unless defined $id;
            $self->children([
                grep { _rel_id($_) ne $id } _build_rel( @{$children} )
            ]);
        }
    }

    # save action for later (when save is called)
    my $delete_buffer = defined $self->delete_buffer
        ? $self->delete_buffer
        : $self->delete_buffer({});
    for my $obj (@objs) {
        $delete_buffer->{ refaddr $obj } = $obj;
    }
}

sub collection {
    my $self = shift;
    defined $self->with_class
        and return $self->with_class->collection;
}

sub with_collection_name {
    my $self = shift;
    defined $self->_with_collection_name
        and return $self->_with_collection_name;

    $self->_with_collection_name( Mongoose->class_config($self->with_class)->{collection_name} );
}

sub _insert {    #TODO insert and commit
}

sub _save {
    my ( $self, $parent, @scope ) = @_;

    my $children = delete $self->{children};
    if( ref $children eq 'Mongoose::Join' ) {
        $children = $children->children;
    }
    my @objs = _build_rel( @{$children ||[]} );

    my $collection_name = $self->with_collection_name;

    # load buffers
    my $buffer = delete $self->{buffer};
    my $delete_buffer = delete $self->{delete_buffer};

    # save buffered children
    for ( keys %{ $buffer } ) {
        my $obj = delete $buffer->{$_};
        next if exists $delete_buffer->{ refaddr $obj };
        $obj->save( @scope );
        push @objs, _build_rel({ '$ref' => $collection_name, '$id' => $obj->_id });
    }

    # adjust
    $self->buffer( $buffer ); # restore the list
    $self->delete_buffer({});

    # make sure unique children is saved
    my %unique = map { _rel_id($_) => $_ } @objs;
    @objs = values %unique;
    $self->children( \@objs );
    return @objs;
}

sub _children_refs {
    my ($self)=@_;
    my @found;
    $self->find->each( sub{
        push @found, _build_rel({ '$ref' => $_[0]->_collection_name, '$id' => $_[0]->{_id} });
    });
    return @found;
}

sub find {
    my ( $self, $opts, @scope ) = @_;
    my $class = $self->with_class;
    $opts ||= {};
    my $children = $self->children;
    if( ref $children eq 'Mongoose::Join' ) {
        $children = $children->children;
    }
    my @children = map { _rel_id($_) } _build_rel( @{$children ||[]} );

    $opts->{_id} = { '$in' => \@children };
    return $class->find( $opts, @scope );
}

sub count {
    my $self = shift;
    $self->_call_rel_method( count => @_ );
}

sub find_one {
    my $self = shift;
    $self->_call_rel_method( find_one => @_ );
}

sub _call_rel_method {
    my ( $self, $method, $opts, @scope ) = @_;
    my $class = $self->with_class;

    $opts ||= {};
    $opts->{_id} = { '$in' => [ map { _rel_id($_) } _build_rel( @{$self->children ||[]} ) ] };

    return $class->$method( $opts, @scope );
}

sub first { shift->find_one }

sub query {
    my ( $self, $opts, $attrs, @scope ) = @_;
    my $class = $self->with_class;
    $opts ||= {};
    my @children = map { _rel_id($_) } _build_rel( @{$self->children ||[]} );
    $opts->{_id} = { '$in' => \@children };
    return $class->query( $opts, $attrs, @scope );
}

sub all {
    my $self = shift;
    return $self->find(@_)->all;
}

sub hash_on {
    my $self = shift;
    my $key = shift;
    my %hash;
    map {
        $hash{ $_->{$key} } = $_ unless exists $hash{ $_->{$key} };
    } $self->find(@_)->all;
    return %hash;
}

sub hash_array {
    my $self = shift;
    my $key = shift;
    my %hash;
    map {
        push @{ $hash{ $_->{$key} } }, $_;
    } $self->find(@_)->all;
    return %hash;
}

# make sure all refs what's expected on the MongoDB driver in use
sub _build_rel {
    for (@_) {
        if ($API_V1) {
            $_ = MongoDB::DBRef->new( ref => $_->{'$ref'}, id => $_->{'$id'} )
                unless ref $_ eq 'MongoDB::DBRef';
        }
        else {
             $_ = Tie::IxHash->new( '$ref' => $_->{'$ref'}, '$id' => $_->{'$id'} )
                unless ref $_ eq 'Tie::IxHash';
        }
    }
    @_;
}

# Read rel ID from ref type in use depending on driver version
sub _rel_id { $API_V1 ? $_[0]->id : $_[0]->FETCH('$id') }

=head1 NAME

Mongoose::Join - simple class relationship resolver

=head1 SYNOPSIS

    package Author;
    use Moose;
    with 'Mongoose::Document';
    has 'articles' => (
        is      => 'rw',
        isa     => 'Mongoose::Join[Article]',
        default => sub { Mongoose::Join->new( with_class => 'Article' ) }
    );

=head1 DESCRIPTION

This module can be used to establish relationships
between two C<Mongoose::Document> classes. It should not
be used with C<Mongoose::EmbeddedDocument> classes.

All object relationships are stored as reference C<$id> arrays
into the parent object. This translates into a slight performance hit
when loading the parent class, but not as much as loading all
objects at one as when using an C<ArrayRef>.

B<Attention>: the relationship attribute needs to be initialized to
an instance of C<Mongoose::Join> before it can be used.

=head2 Mongoose::Class

Take a look at L<Mongoose::Class>, it has nice syntatic sugar
that does most of the initialization behind the scenes for you.

=head1 METHODS

=head2 add

Add (join) a Mongoose::Document object for later saving.

Saving the parent Mongoose::Document will save both.

    my $author = Author->new;
    $author->articles->add( Article->new );
    $author->save; # saves all objects

=head2 remove

Delete from the relationship list.

    my $author = Author->find_one;
    my $first_article = $author->articles->find_one;
    $author->articles->remove( $first_article );

=head2 find

Run a MongoDB C<find> on the joint collection.

    # searches for articles belonging to this collection
    my $cursor = $author->articles->find({ title=>'foo article' });
    while( my $article = $cursor->next ) {
        ...
    }

Returns a L<Mongoose::Cursor>.

=head2 count

Count relations.

=head2 find_one

Just like find, but returns the first row found.

=head2 first

Alias to C<find_one>

    $first_cd = $artist->cds->first;

=head2 all

Same as C<find>, but returns an ARRAY with all the results, instead
of a cursor.

    my @cds = $artist->cds->all;

=head2 hash_on

Same as C<all>, but returns a HASH instead of an ARRAY.
The hash will be indexed by the key name sent as the first parameter.
The hash value contains exactly one object. In case duplicate rows
with the same key value are found, the resulting hash will contain
the first one found.

    # ie. returns $cds{'111888888292adf0000003'} = <CD Object>;
    my %cds = $artist->cds->hash_on( '_id' => { artist=>'Joe' });

    # ie. returns $joe_cds{'Title1'} = <CD Object>;
    my %joe_cds = $artist->cds->hash_on( 'title' => { artist=>qr/Joe/ });

=head2 hash_array

Similar to C<hash_on>, but returns a hash with ALL rows found, grouped
by the key.

    # ie. returns $cds{'Title1'} = [ <CD1 Object>, <CD2 Object>, ... ];
    my %cds = $artist->cds->hash_array( 'title' => { artist=>'Joe' });

Hash values are ARRAYREFs with 1 or more rows.

=head2 query

Run a MongoDB C<query> on the joint collection.

=head2 collection

Returns the L<MongoDB::Collection> for the joint collection.

=head2 with_collection_name

Return the collection name for the joint Mongoose::Document.

=cut

__PACKAGE__->meta->make_immutable();
