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

sub add{
    my ( $self, @objs ) = @_;
    use Scalar::Util qw(refaddr);
    for my $obj ( @objs ){
        $obj->{$self->reciprocal} = $self->owner;
        $self->buffer->{ refaddr $obj } = $obj;
    }
}

sub find{
    my ( $self, $opts, @scope ) = @_;
    my $class = $self->with_class;
    use Data::Dumper;
    print Dumper { $self->reciprocal => $self->owner};
    return $class->find( { $self->reciprocal => $self->owner}, @scope ); #We find based on a reference in the Ball objects
}

sub _save{
    my ( $self, $parent, @scope ) = @_;
    my $buffer = delete $self->{buffer};
    for ( keys %{ $buffer } ) {
        my $obj = delete $buffer->{$_};
        $obj->save( @scope );
    }
}



1;

