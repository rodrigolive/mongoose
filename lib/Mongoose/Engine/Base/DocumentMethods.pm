package Mongoose::Engine::Base::DocumentMethods;
use Moose::Role;
use Mongoose::Resultset;


#Resultset methods
sub resultset{ my $self = shift; return Mongoose::Resultset->new( _class => ref $self || $self ); }
sub search {return ( wantarray ? shift->resultset->search( @_ )->all : shift->resultset->search( @_ ) ); }
sub find {return ( wantarray ? shift->resultset->find( @_ )->all : shift->resultset->find( @_ ) ); }
sub query {return ( wantarray ? shift->resultset->query( @_ )->all : shift->resultset->query( @_ ) ); }
sub find_one {return shift->resultset->find_one( @_ );}
#sub first { return shift->resultset->first; } #This make everything bug for some weird reason
sub find_or_new { return shift->resultset->find_or_new( @_ ); }
sub find_or_create { return shift->resultset->find_or_create( @_ ); }
#sub update {} #not needed, the document's update method calls the resultset if we are an unblessed class
sub update_all { return shift->resultset->update_all( @_ ); }
sub update_or_create { return shift->resultset->update_or_create( @_ ); }
sub update_or_new { return shift->resultset->update_or_new( @_ ); }
#sub delete {} #not needed, the document's delete method calls the resultset if we are an unblessed class
sub remove { return shift->resultset->remove( @_ ); }
sub delete_all { return shift->resultset->delete_all( @_ ); }
sub remove_all { return shift->resultset->remove_all( @_ ); }
sub next { return shift->resultset->next( @_ ); }
sub count { return shift->resultset->count( @_ ); }
sub all { return shift->resultset->all( @_ ); }
sub cursor { return shift->resultset->cursor( @_ ); }
sub each { return shift->resultset->each( @_ ); }
sub new_result { return shift->resultset->new_result( @_ ); }
sub create { return shift->resultset->create( @_ ); }
sub skip { return shift->resultset->skip( @_ ); }
sub limit { return shift->resultset->limit( @_ ); }
sub sort_by { return shift->resultset->sort_by( @_ ); }
sub fields { return shift->resultset->fields( @_ ); }

#Document methods
sub insert {
    my $self = shift;
    return $self if $self->in_storage;
    $self->save;
    $self = $self->resultset->find_one({ _id => $self->_id });
    return $self;
}

sub update {
    my $self = shift;
    return $self->resulset->update(@_) if ref $self eq ''; #When calling on the unblessed class, we call the resultset
    my ( $modification ) = @_;
    $self->collection->update( { _id => $self->_id }, $modification );
    $self = $self->resultset->find_one({ _id => $self->_id });
    return $self;
}

# shallow delete
sub delete {
    my $self = shift;
    return $self->resulset->delete(@_) if ref $self eq ''; #When calling on the unblessed class, we call the resultset
    my ( $args ) = @_;
    
	return $self->collection->remove($args) if ref $args;
	my $id = $self->_id;
	return $self->collection->remove({ _id => $id }) if ref $id;
	my $pk = $self->_primary_key_from_hash();
	return $self->collection->remove($pk) if ref $pk;
	return undef;
}


#TODO IMPORTANT
sub in_storage {

}


1;

