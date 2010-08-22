use Moose;
use MooseX::Types;
use MooseX::Types::Parameterizable qw(Parameterizable);
use MooseX::Types::Moose qw(Int Item Any Maybe);
use MooseX::Types -declare=>[qw(MongooseCollection)];
use Moose::Util::TypeConstraints;

subtype MongooseCollection,
as Parameterizable[Item],
where {
	warn "OK=", @_;
},
message { "not ok" };
	 
#my $REGISTRY = Moose::Meta::TypeConstraint::Registry->new;
#Moose::Util::TypeConstraints::add_parameterizable_type( $REGISTRY->get_type_constraint( 'MongooseCollection' ) );

1;
