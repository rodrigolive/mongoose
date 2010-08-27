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


after add => sub {
    my ( $self, @objs ) = @_;
    for my $obj ( @objs ){
        if( $obj->meta->get_attribute($self->reciprocal)->type_constraint !~ m{^Mongoose::Join::Relational} ){
            $obj->{$self->reciprocal} = $self->owner;
        }
    }
};


sub find {
    my $self = shift;
    my ( $opts, @scope ) = @_;
    my $class = $self->with_class;
    $opts = $opts || {};
    
    if( $self->with_class->meta->get_attribute($self->reciprocal)->type_constraint !~ m{^Mongoose::Join::Relational} ){
        return $class->find( { $self->reciprocal => $self->owner, %$opts }, @scope ); 
    }else{
        $opts->{$self->reciprocal . '.$id'} = $self->owner->_id;
        return $class->find( $opts, @scope );
    }
}

sub find_one{
    my $self = shift;
    my ( $opts, @scope ) = @_;
    my $class = $self->with_class;
    $opts = $opts || {};
    
    if( $self->with_class->meta->get_attribute($self->reciprocal)->type_constraint !~ m{^Mongoose::Join::Relational} ){
        return $class->find_one( { $self->reciprocal => $self->owner, %$opts }, @scope ); 
    }else{
        $opts->{$self->reciprocal . '.$id'} = $self->owner->_id;
        return $class->find_one( $opts, @scope );
    }
}

1;

