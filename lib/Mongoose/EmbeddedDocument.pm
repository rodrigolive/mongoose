package Mongoose::EmbeddedDocument;

use MooseX::Role::Parameterized;
use Mongoose::Meta::AttributeTraits;

parameter '-engine' => ( isa => 'Mongoose::Role::Engine' );
parameter '-pk'     => ( isa => 'ArrayRef[Str]' );

role {
	my $p = shift;
	with 'Mongoose::Document' => $p;
};

=head1 NAME

Mongoose::EmbeddedDocument - role for embedded documents

=head1 SYNOPSIS

	package Address;
	use Moose;
	with 'Mongoose::EmbeddedDocument';
	has 'street' => is=>'rw', isa=>'Str';

	package Person;
	use Moose;
	with 'Mongoose::Document';
	has 'address' => ( is=>'rw', isa=>'Address' );

=head1 DESCRIPTION

This role is a copy of C<Mongoose::Document>, but flags the class
as 'embedded' so that it's collapsed into a single parent document
in the database. 

=head1 SEE ALSO

Read the Mongoose intro or cookbook. 

From the MongoDB docs: L<http://www.mongodb.org/display/DOCS/Updating+Data+in+Mongo#UpdatingDatainMongo-EmbeddingDocumentsDirectlyinDocuments>

=cut

1;
