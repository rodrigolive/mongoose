package Mongoose::Document;
use MooseX::Role::Parameterized;
use Mongoose::Meta::AttributeTraits;

parameter '-engine' => (
	isa      => 'Mongoose::Role::Engine',
);

parameter '-collection_name' => (
	isa      => 'Str',
);

parameter '-pk' => (
	isa      => 'ArrayRef[Str]',
);

parameter '-as' => (
	isa      => 'Str',
);

role {
	my $p = shift;
	my %args = @_;
	my $class_name = $args{consumer}->name;

	my $collection_name = $p->{'-collection_name'} || do {
		# sanitize the class name
		Mongoose->naming->( $class_name );
	};
	my $engine = $p->{'-engine'} || 'Mongoose::Engine::Base';
	Class::MOP::load_class($engine);

	# import the engine role
	with $engine;

	# aliasing
	if( my $as = $p->{'-as'} ) {
		#my $as_class = Moose::Meta::Class->create( $as, superclasses=>[ $class_name ] );
		no strict;
		*{$as . "::"} = \*{$class_name . "::"};
	}

	# attributes
	has '_id' => ( is=>'rw', isa=>'MongoDB::OID', traits=>['DoNotSerialize'] );

	my $config  = {
		pk => $p->{'-pk'},
		collection_name => $collection_name,
	};
	method "_mxm_config" => sub{ $config };
};

1;
