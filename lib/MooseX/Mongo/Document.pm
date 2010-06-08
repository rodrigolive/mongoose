package MooseX::Mongo::Document;
use MooseX::Role::Parameterized;
use MooseX::Mongo::Meta::Attribute::DoNotSerialize;

    parameter 'engine' => (
        isa      => 'MooseX::Mongo::Role::Engine',
    );

    parameter 'collection_name' => (
        isa      => 'Str',
    );

    parameter 'pk' => (
        isa      => 'ArrayRef[Str]',
    );

parameter 'engine' => ( isa => 'MooseX::Mongo::Role::Engine' );
parameter 'pk'     => ( isa => 'ArrayRef[Str]' );

role {
	my $p = shift;
	my %args = @_;
	use v5.10;
	my $collection_name = $p->{collection_name} || do {
		# sanitize the class name
		my $name = $args{consumer}->name;
		MooseX::Mongo->naming->( $name );
	};
	my $engine = $p->engine || 'MooseX::Mongo::Engine::Base';
	Class::MOP::load_class($engine);
	with $engine;

	has '_id' => ( is=>'rw', isa=>'MongoDB::OID', metaclass=>'DoNotSerialize' );

	my $config  = {
		pk => $p->pk,
		collection_name => $collection_name,
	};
	method "_mxm_config" => sub{ $config };
};

1;
