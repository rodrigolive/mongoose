package Mongoose::Join;
use Moose;
use Moose::Util::TypeConstraints;
use Moose::Meta::TypeConstraint::Parameterizable;
use Moose::Meta::TypeConstraint::Registry;

my $REGISTRY = Moose::Meta::TypeConstraint::Registry->new;
$REGISTRY->add_type_constraint(
    Moose::Meta::TypeConstraint::Parameterizable->new(
        name               => 'Mongoose::Join',
        package_defined_in => __PACKAGE__,
        parent             => find_type_constraint('Item'),
        constraint         => sub { die 'constrained' },
        constraint_generator => sub {
            my $type_parameter = shift;
            #print "constraint_generator...@_\n";
            return sub { return {} };
        }
    )
);

Moose::Util::TypeConstraints::add_parameterizable_type( $REGISTRY->get_type_constraint( 'Mongoose::Join' ) );

has 'class' => (is=>'rw', isa=>'Str' );
has 'with_class' => (is=>'rw', isa=>'Str' );
has '_with_collection_name' => (is=>'rw', isa=>'Str' );
has 'parent' => (is=>'rw', isa=>'MongoDB::OID' );
has 'children' => (is=>'rw', isa=>'ArrayRef' );
has 'buffer' => (is=>'rw', isa=>'HashRef', default=>sub{{}} );

use Scalar::Util qw/refaddr/;

sub add {
    my ($self, @objs) = @_;
    for( @objs ) {
        $self->buffer->{ refaddr $_ } = $_; 
    }
}

sub with_collection_name {
    my $self = shift;
    defined $self->_with_collection_name
        and return $self->_with_collection_name;
    return $self->_with_collection_name(
        $self->with_class->meta->{mongoose_config}->{collection_name} );
}

sub _insert {  #TODO insert and commit
}

sub _save {
    my ($self, $parent, @scope )=@_;
    #die 'parent=' . x::pp( $parent );
    my @objs;
    my $collection_name = $self->with_collection_name;
    for( keys %{ $self->buffer } ) {
        my $obj = delete $self->buffer->{$_};
        $obj->save;
        push @objs, { '$ref'=>$collection_name, '$id'=>$obj->_id };
    }
    return @objs;
}

sub find {
    my ($self, $opts, @scope ) = @_;
    my $class = $self->with_class;
    $opts ||= {};
    my @children = map { $_->{'$id'} } @{ $self->children || [] };
    $opts->{_id} = { '$in' => \@children };
    return $class->find( $opts, @scope );
}

sub query {
    my ($self, $opts, $attrs, @scope ) = @_;
    my $class = $self->with_class;
    $opts ||= {};
    my @children = map { $_->{'$id'} } @{ $self->children || [] };
    $opts->{_id} = { '$in' => \@children };
    return $class->query( $opts, $attrs, @scope );
}

sub all {
    my $self = shift;
    return $self->find( @_ )->all;
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

=head2 find

Run a MongoDB C<find> on the joint collection.

    # searches for articles belonging to this collection
    my $cursor = $author->articles->find({ title=>'foo article' });
    while( my $article = $cursor->next ) {
        ...
    }

Returns a L<Mongoose::Cursor>. 

=head2 all

Same as C<find>, but returns an ARRAY with all the results, instead 
of a cursor. 

=head2 query

Run a MongoDB C<query> on the joint collection.

=head2 with_collection_name

Return the collection name for the joint Mongoose::Document.

=cut

1;
