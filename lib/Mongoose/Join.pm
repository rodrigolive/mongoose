package Mongoose::Join;
use Moose;
use Moose::Util::TypeConstraints;
use Moose::Meta::TypeConstraint::Parameterizable;
use Moose::Meta::TypeConstraint::Registry;

my $REGISTRY = Moose::Meta::TypeConstraint::Registry->new;
$REGISTRY->add_type_constraint(
    Moose::Meta::TypeConstraint::Parameterizable->new(
        name                 => 'Mongoose::Join',
        package_defined_in   => __PACKAGE__,
        parent               => find_type_constraint('Item'),
        constraint           => sub { die 'constrained' },
        constraint_generator => sub {
            my $type_parameter = shift;

            #print "constraint_generator...@_\n";
            return sub { return {} };
        }
    )
);

Moose::Util::TypeConstraints::add_parameterizable_type(
    $REGISTRY->get_type_constraint('Mongoose::Join') );

has 'class'                 => ( is => 'rw', isa => 'Str' );
has 'with_class'            => ( is => 'rw', isa => 'Str' );
has '_with_collection_name' => ( is => 'rw', isa => 'Str' );
has 'parent'                => ( is => 'rw', isa => 'MongoDB::OID' );

# once the object is expanded, it has children too
has 'children'              => ( is => 'rw', isa => 'ArrayRef' );

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
            my $id = $obj->{_id};
            next unless defined $id; 
            $self->children([
                grep { $_->{'$id'} ne $id } @{ $children } 
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
    return $self->_with_collection_name(
        $self->with_class->meta->{mongoose_config}->{collection_name} );
}

sub _insert {    #TODO insert and commit
}

sub _save {
    my ( $self, $parent, @scope ) = @_;

    my @objs = @{ delete $self->{children} || [] };
    my $collection_name = $self->with_collection_name;

    # load buffers
    my $buffer = delete $self->{buffer};
    my $delete_buffer = delete $self->{delete_buffer};

    # save buffered children
    for ( keys %{ $buffer } ) {
        my $obj = delete $buffer->{$_};
        next if exists $delete_buffer->{ refaddr $obj };
        $obj->save( @scope );
        push @objs, { '$ref' => $collection_name, '$id' => $obj->_id };
    }

    # adjust
    $self->buffer( $buffer ); # restore the list
    $self->delete_buffer({});

    # make sure unique children is saved
    my %unique = map { $_->{'$id'} => $_ } @objs;
    @objs = values %unique;
    $self->children( \@objs );
    return @objs;
}

sub find {
    my ( $self, $opts, @scope ) = @_;
    my $class = $self->with_class;
    $opts ||= {};
    my @children = map { $_->{'$id'} } @{ $self->children || [] };
    $opts->{_id} = { '$in' => \@children };
    return $class->find( $opts, @scope );
}

sub find_one {
    my ( $self, $opts, @scope ) = @_;
    my $class = $self->with_class;
    $opts ||= {};
    my @children = map { $_->{'$id'} } @{ $self->children || [] };
    $opts->{_id} = { '$in' => \@children };
    return $class->find_one( $opts, @scope );
}

sub query {
    my ( $self, $opts, $attrs, @scope ) = @_;
    my $class = $self->with_class;
    $opts ||= {};
    my @children = map { $_->{'$id'} } @{ $self->children || [] };
    $opts->{_id} = { '$in' => \@children };
    return $class->query( $opts, $attrs, @scope );
}

sub all {
    my $self = shift;
    return $self->find(@_)->all;
}

=head1 NAME

Mongoose::Join - simple class relationship resolver

=head1 SYNOPSIS

    package Author;
    use Moose; with 'Mongoose::Document';
    has 'articles'  => ( is => 'rw', isa => 'Mongoose::Join[Article]' );

=head1 DESCRIPTION

This module can be used to parameterize relationships 
between two C<Mongoose::Document> classes. It should not
be used for C<Mongoose::EmbeddedDocument> classes.  

All object relationships are stored as reference C<$id> arrays
in the parent object, which translates into a performance hit
when loading the parent class, but not as much as loading all 
objects at one as when using an C<ArrayRef>. 

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

=head2 find_one

Just like find, but with a C<find_one> twist. 

=head2 all

Same as C<find>, but returns an ARRAY with all the results, instead 
of a cursor. 

=head2 query

Run a MongoDB C<query> on the joint collection.

=head2 collection

Returns the L<MongoDB::Collection> for the joint collection.

=head2 with_collection_name

Return the collection name for the joint Mongoose::Document.

=cut

1;
