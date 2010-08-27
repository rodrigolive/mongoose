package Mongoose::Join::Relational;
use Moose;
use Data::Dumper;
extends 'Mongoose::Join';

has child_reciprocal => ( isa => 'Str', is => 'rw');
has with_class => ( isa => 'Str', is => 'rw');
has owner => ( isa => 'Any', is => 'rw');
has buffer => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

sub add{
    my ( $self, @objs ) = @_;
    use Scalar::Util qw(refaddr);
    for my $obj ( @objs ){
        $obj->{$self->child_reciprocal} = $self->owner;
        $self->buffer->{ refaddr $obj } = $obj;
    }
}

sub find{
    my ( $self, $opts, @scope ) = @_;
    my $class = $self->with_class;
    return $class->find( { $self->child_reciprocal => $self->owner}, @scope ); #We find based on a reference in the Ball objects
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

