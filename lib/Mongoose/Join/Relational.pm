package Mongoose::Join::Relational;
use Moose;
use Data::Dumper;
extends 'Mongoose::Join';

use Moose::Util::TypeConstraints;
use Moose::Meta::TypeConstraint::Parameterizable;
use Moose::Meta::TypeConstraint::Registry;

my $REGISTRY = Moose::Meta::TypeConstraint::Registry->new;
$REGISTRY->add_type_constraint(
    Moose::Meta::TypeConstraint::Parameterizable->new(
        name                 => 'Mongoose::Join::Relational',
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
    $REGISTRY->get_type_constraint('Mongoose::Join::Relational') );

has reciprocal => ( isa => 'Str', is => 'rw');
has owner => ( isa => 'Any', is => 'rw');

use Scalar::Util qw/refaddr/;

sub _save {
    my ( $self, $parent, @scope ) = @_;

    my @objs = @{ delete $self->{children} || [] };
    my $collection_name = $self->with_collection_name;

    # load buffers
    my $buffer = delete $self->{buffer};
    my $delete_buffer = delete $self->{delete_buffer};

    # save deleted, couldn't see how to put this in Join::Relational without creating infinte loops
    for my $deleted ( values %{$delete_buffer}){
        $deleted->save;
    }

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
    
    #We collapse into a list only if we are in a many-to-many configuration
    return @objs if $self->with_class->meta->get_attribute($self->reciprocal)->type_constraint =~ m{^Mongoose::Join::Relational};
    return ();
}

around remove => sub {
    my ( $orig, $self, @objs ) = @_;
    
    my $recurse = 1; if( $objs[0] eq 'no_recursion'){ $recurse = 0; shift @objs; }
    
    for my $obj ( @objs ){
        if( $obj->meta->get_attribute($self->reciprocal)->type_constraint !~ m{^Mongoose::Join::Relational} ){
            delete $obj->{$self->reciprocal};
        }else{
            $obj->{$self->reciprocal}->remove('no_recursion', $self->owner) if $recurse;
        }
    }
    return $self->$orig(@objs);
};


around add => sub {
    my ( $orig, $self, @objs ) = @_;

    my $recurse = 1; if( $objs[0] eq 'no_recursion'){ $recurse = 0; shift @objs; }
    
    for my $obj ( @objs ){
        #next if grep { } 
        if( $obj->meta->get_attribute($self->reciprocal)->type_constraint !~ m{^Mongoose::Join::Relational} ){
            $obj->{$self->reciprocal} = $self->owner;
        }else{
            $obj->{$self->reciprocal}->add('no_recursion', $self->owner) if $recurse;
        }
    }
    return $self->$orig(@objs);
};


sub find {
    my $self = shift;
    my ( $opts, @scope ) = @_;
    my $class = $self->with_class;
    $opts = $opts || {};
    
    #if( $self->with_class->meta->get_attribute($self->reciprocal)->type_constraint !~ m{^Mongoose::Join::Relational} ){
        #print Dumper { $self->reciprocal => $self->owner, %$opts };
        #print $self->reciprocal , " ",  $self->owner, "\n";
        #return $class->find( { $self->reciprocal => $self->owner, %$opts }, @scope );
        $opts->{$self->reciprocal . '.$id'} = $self->owner->_id;
        return $class->find( $opts, @scope );
    #}else{
    #    $opts->{$self->reciprocal . '.$id'} = $self->owner->_id;
    #    return $class->find( $opts, @scope );
    #}
}

sub find_one{
    my $self = shift;
    my ( $opts, @scope ) = @_;
    my $class = $self->with_class;
    $opts = $opts || {};
    
    #if( $self->with_class->meta->get_attribute($self->reciprocal)->type_constraint !~ m{^Mongoose::Join::Relational} ){
    #    return $class->find_one( { $self->reciprocal => $self->owner, %$opts }, @scope ); 
    #}else{
        $opts->{$self->reciprocal . '.$id'} = $self->owner->_id;
        return $class->find_one( $opts, @scope );
    #}
}

sub query{
    my $self = shift;
    my ( $opts, $attrs, @scope ) = @_;
    my $class = $self->with_class;
    $opts = $opts || {};
    
    #if( $self->with_class->meta->get_attribute($self->reciprocal)->type_constraint !~ m{^Mongoose::Join::Relational} ){
    #    return $class->query( { $self->reciprocal => $self->owner, %$opts }, $attrs, @scope ); 
    #}else{
        $opts->{$self->reciprocal . '.$id'} = $self->owner->_id;
        return $class->query( $opts, $attrs, @scope );
    #}
}

1;

