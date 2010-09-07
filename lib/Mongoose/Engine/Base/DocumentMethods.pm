package Mongoose::Engine::Base::DocumentMethods;
use Moose::Role;
use Mongoose::Resultset;

sub resultset{
    my $self = shift;
    return Mongoose::Resultset->new( _class => ref $self || $self );
}

sub find {
	my ($self,$query,$attrs) = @_;
    return $self->resultset->find( $query, $attrs );
}

sub query {
	my ($self,$query,$attrs) = @_;
    return $self->resultset->query( $query, $attrs );
}

sub find_one {
	my ($self,$query,$attrs) = @_;
    return $self->resultset->find_one( $query, $attrs );
}

sub insert {
    my $self = shift;
    return $self if $self->in_storage;
    $self->save;
    return $self;
}

sub update {
    my ( $self, $values ) = @_;
    map { $self->{$_} = $values->{$_} } keys %{$values};
    $self->save;
    return $self;
}

#TODO IMPORTANT
sub in_storage {

}


1;

