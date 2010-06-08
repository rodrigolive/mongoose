package MooseX::Mongo::EmbeddedDocument;
use MooseX::Role::Parameterized;
use MooseX::Mongo::Meta::Attribute::DoNotSerialize;

parameter 'engine' => ( isa => 'MooseX::Mongo::Role::Engine' );
parameter 'pk'     => ( isa => 'ArrayRef[Str]' );

role {
	my $p = shift;
	with 'MooseX::Mongo::Document' => $p;
};

1;
