package Mongoose::EmbeddedDocument;
use MooseX::Role::Parameterized;
use Mongoose::Meta::AttributeTraits;

parameter 'engine' => ( isa => 'Mongoose::Role::Engine' );
parameter 'pk'     => ( isa => 'ArrayRef[Str]' );

role {
	my $p = shift;
	with 'Mongoose::Document' => $p;
};

1;
