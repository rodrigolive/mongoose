package Mongoose::Engine::Serialize;

use Moose::Role;
use MooseX::Storage;
with Storage;

with 'Mongoose::Engine::Base';

sub collapse {
	return shift->pack;
}

sub expand {
	my ($self,$doc)=@_;
	my $coll_name = $self->collection_name;
	return $coll_name->unpack( $doc );
}

=head1 NAME

Mongoose::Engine::Serialize

=head1 DESCRIPTION

An alternative, undocumented engine based on L<MooseX::Storage>.

=head1 METHODS

=head2 collapse

Collapses an object using pack.

=head2 expand

Expands an object using unpack.

=cut

1;
