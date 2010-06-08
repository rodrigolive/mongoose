package MooseX::Mongo::Engine::Serialize;
use Moose::Role;
use MooseX::Storage;
with Storage;

with 'MooseX::Mongo::Engine::Base';

sub collapse {
	return shift->pack;
}

sub expand {
	my ($self,$doc)=@_;
	my $coll_name = $self->collection_name;
	return $coll_name->unpack( $doc );
}

package DocumentID;
use Moose;
extends 'MongoDB::OID';

1;
