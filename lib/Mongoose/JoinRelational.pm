package Mongoose::JoinRelational;
use Moose;
use Data::Dumper;
extends 'Mongoose::Join';

use Moose::Util::TypeConstraints;
use Moose::Meta::TypeConstraint::Parameterizable;
use Moose::Meta::TypeConstraint::Registry;

my $REGISTRY = Moose::Meta::TypeConstraint::Registry->new;
$REGISTRY->add_type_constraint(
    Moose::Meta::TypeConstraint::Parameterizable->new(
        name                 => 'Mongoose::JoinRelational',
        package_defined_in   => __PACKAGE__,
        parent               => find_type_constraint( 'Item' ),
        constraint           => sub { die 'constrained' },
        constraint_generator => sub {
            my $type_parameter = shift;

            #print "constraint_generator...@_\n";
            return sub { return {} };
        }
    )
);

Moose::Util::TypeConstraints::add_parameterizable_type( $REGISTRY->get_type_constraint( 'Mongoose::JoinRelational' ) );

has reciprocal => ( isa => 'Str', is => 'rw' );
has owner      => ( isa => 'Any', is => 'rw' );

use Scalar::Util qw/refaddr blessed/;

sub _save {
    my ( $self, $parent, @scope ) = @_;

    my @objs = @{ delete $self->{ children } || [] };
    my $collection_name = $self->with_collection_name;

    # load buffers
    my $buffer        = delete $self->{ buffer };
    my $delete_buffer = delete $self->{ delete_buffer };

    # save deleted, couldn't see how to put this in JoinRelational
    #   without creating infinte loops // 4 months later this sentence makes no sense.
    for my $deleted ( values %{ $delete_buffer } ) {
        $deleted->save;
    }

    # save buffered children
    for ( keys %{ $buffer } ) {
        my $obj = delete $buffer->{ $_ };
        next if exists $delete_buffer->{ refaddr $obj };
        $obj->save( @scope );
        push @objs, { '$ref' => $collection_name, '$id' => $obj->_id };
    }

    # adjust
    $self->buffer( $buffer );    # restore the list
    $self->delete_buffer( {} );

    # make sure unique children is saved
    my %unique = map { $_->{ '$id' } => $_ } grep { defined } @objs;
    @objs = values %unique;
    $self->children( \@objs );

    # We collapse into a list only if we are in a many-to-many configuration
    return @objs
        if defined $self->reciprocal
            && $self->with_class->meta->get_attribute( $self->reciprocal )->type_constraint =~ m{^Mongoose::JoinRelational};
    return undef;
}

sub delete { shift->remove( @_ ); }

around remove => sub {
    my ( $orig, $self, @objs ) = @_;
    my $recurse = 1;
    if ( $objs[ 0 ] eq 'no_recursion' ) { $recurse = 0; shift @objs; }

    if ( scalar @objs and blessed $objs[ 0 ] ) {
        for my $obj ( @objs ) {
            if ( $obj->meta->get_attribute( $self->reciprocal )->type_constraint !~ m{^Mongoose::JoinRelational} ) {
                delete $obj->{ $self->reciprocal };
            }
            else {
                $obj->{ $self->reciprocal }->remove( 'no_recursion', $self->owner ) if $recurse;
            }
            $obj->save;
        }
        return $self->$orig( @objs );
    }
    else {
        return $self->resultset->delete( @objs );
    }
};

sub delete_all { shift->remove_all( @_ ) }

sub remove_all {
    my ( $self, $options ) = @_;
    return $self->resultset->delete_all( $options );
}

around add => sub {
    my ( $orig, $self, @objs ) = @_;
    my $recurse = 1;
    if ( $objs[ 0 ] eq 'no_recursion' ) { $recurse = 0; shift @objs; }
    for my $obj ( @objs ) {

        if ( $obj->meta->get_attribute( $self->reciprocal )->type_constraint !~ m{^Mongoose::JoinRelational} ) {
            $obj->{ $self->reciprocal } = $self->owner;
        }
        else {
            $obj->{ $self->reciprocal }->add( 'no_recursion', $self->owner ) if $recurse;
        }
    }
    return $self->$orig( @objs );
};

sub search { shift->find( @_ ); }

sub find {
    my ( $self, $opts, @scope ) = @_;
    $opts = $opts || {};
    return $self->resultset->find( $opts, @scope );
}

sub query {
    my ( $self, $opts, $attrs, @scope ) = @_;
    $opts = $opts || {};
    return $self->resultset->query( $opts, $attrs, @scope );
}

sub single { shift->find_one( @_ ) }

sub find_one {
    my ( $self, $opts, @scope ) = @_;
    $opts = $opts || {};
    return $self->resultset->find_one( $opts, @scope );
}

sub first {
    return shift->resultset->first;
}

sub find_or_new {
    my $self = shift;
    my $obj  = $self->resultset->find_or_new( @_ );
    $self->add( $obj );
    return $obj;
}

sub find_or_create {
    my $self = shift;
    my $obj  = $self->resultset->find_or_create( @_ );
    $self->add( $obj );

    #$self->owner->save;
    $obj->save;
    return $obj;
}

sub update {
    my $self = shift;
    return $self->resultset->update( @_ );
}

sub update_all {
    my $self = shift;
    return $self->resultset->update_all( @_ );
}

sub update_or_create {
    my $self = shift;
    my $obj  = $self->resultset->update_or_create( @_ );
    unless ( @_{ $self->reciprocal } ) {
        if ( $obj->meta->get_attribute( $self->reciprocal )->type_constraint !~ m{^Mongoose::JoinRelational} ) {
            $obj->{ $self->reciprocal } = $self->owner;
            $obj->save;
        }
        else {
            $obj->{ $self->reciprocal }->add( 'no_recursion', $self->owner );
            $obj->save;
        }
    }
    $self->add( $obj );
    $self->owner->save;
    return $obj;
}

sub update_or_new {
    my $self = shift;
    my $obj  = $self->resultset->update_or_new( @_ );
    unless ( @_{ $self->reciprocal } ) {
        if ( $obj->meta->get_attribute( $self->reciprocal )->type_constraint !~ m{^Mongoose::JoinRelational} ) {
            $obj->{ $self->reciprocal } = $self->owner;
        }
        else {
            $obj->{ $self->reciprocal }->add( 'no_recursion', $self->owner );
        }
    }
    $self->add( $obj );
    return $obj;
}

sub resultset {
    my $self = shift;

#print $self->reciprocal . " => [ '\$ref' => "  , $self->owner->collection->name , ", '\$id' => " , $self->owner->_id , " ]\n";
#return Mongoose::Resultset->new( _class => ref $self->with_class || $self->with_class, _query => { $self->reciprocal . '.$id' => $self->owner->_id } );
    return Mongoose::Resultset->new(
        _class => ref $self->with_class || $self->with_class,
        _query => {

# This did not work due to hash order and $id being an invalid operator : $self->reciprocal => { '$ref' => $self->owner->collection->name, '$id' => $self->owner->_id, }
            $self->reciprocal . '.$ref' => $self->owner->collection->name,
            $self->reciprocal . '.$id'  => $self->owner->_id
        }
    );

}

sub create {
    my $self = shift;
    my %data = @_;
    my $obj  = $self->resultset->create( %data );
    unless ( $data{ $self->reciprocal } ) {

        if ( $obj->meta->get_attribute( $self->reciprocal )->type_constraint !~ m{^Mongoose::JoinRelational} ) {
            $obj->{ $self->reciprocal } = $self->owner;
            $obj->save;
        }
        else {
            $obj->{ $self->reciprocal }->add( 'no_recursion', $self->owner );
            $obj->save;
        }
    }
    $self->add( $obj );
    $self->owner->save;
    return $obj;
}

sub new_result {
    my $self = shift;
    my %data = @_;
    my $obj  = $self->resultset->new_result( %data );
    unless ( $data{ $self->reciprocal } ) {

        if ( $obj->meta->get_attribute( $self->reciprocal )->type_constraint !~ m{^Mongoose::JoinRelational} ) {
            $obj->{ $self->reciprocal } = $self->owner;
        }
        else {
            $obj->{ $self->reciprocal }->add( 'no_recursion', $self->owner );
        }
    }
    $self->add( $obj );
    return $obj;
}


sub each {
    my ( $self, $coderef ) = @_;
    return $self->resultset->each( $coderef );
}

sub skip    { return shift->resultset->skip( @_ ); }
sub limit   { return shift->resultset->limit( @_ ); }
sub sort_by { return shift->resultset->sort_by( @_ ); }
sub fields  { return shift->resultset->fields( @_ ); }

sub count { return shift->resultset->count( @_ ); }

sub all { return shift->resultset->all( @_ ); }


1;

