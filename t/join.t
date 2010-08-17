use strict;
use warnings;
use Test::More;

use Mongoose;
my $db = Mongoose->db( '_mxm_testing' );
$db->run_command({ drop=>'company' }); 
{
    package MongooseCollection;
    use Moose;
	#extends 'Moose::Meta::TypeConstraint::Parameterizable';
    use Moose::Util::TypeConstraints;
	use Moose::Meta::TypeConstraint::Parameterizable;
	use Moose::Meta::TypeConstraint::Registry;
    #subtype 'Mongoose::Collection' => as 'ArrayRef[Any]'; 
    #coerce 'Mongoose::Collection[Employee]' => from 'Any' => via { die 'aaa' };

	my $REGISTRY = Moose::Meta::TypeConstraint::Registry->new;
	$REGISTRY->add_type_constraint(
		Moose::Meta::TypeConstraint::Parameterizable->new(
			name               => 'MongooseCollection',
			package_defined_in => __PACKAGE__,
			parent             => find_type_constraint('Item'),
			constraint         => sub { 1 },
			constraint_generator => sub {
				return 1;
				my $type_parameter = shift;
				my $check          = $type_parameter->_compiled_type_constraint;
				return sub {
					foreach my $x (@$_) {
						( $check->($x) ) || return;
					}
					1;
				}
			}
		)
	);
    coerce 'MongooseCollection' => from 'Item' => via { die 'aaa' };

	Moose::Util::TypeConstraints::add_parameterizable_type( $REGISTRY->get_type_constraint( 'MongooseCollection' ) );
	
}
{
	package Department;
	use Moose;
	with 'Mongoose::Document';
    has 'code' => ( is=>'rw', isa=>'Str');
    #has 'locs' => ( is=>'rw', isa=>'ArrayRef', metaclass=>'Array', default=>sub{[]} );
    has 'employees' => ( is=>'rw', isa=>'MongooseCollection[Employee]' );
    #subtype 'Mongoose::Collection' => as 'Any' => where { print $_ };
}
{
	package Employee;
	use Moose;
	with 'Mongoose::Document';
	has 'name' => ( is=>'rw', isa=>'Str', required=>1 );
}

package main;
{
    my $e = Employee->new( name=>'Bob' );
    my $c = Department->new( code=>'ACC' );
	#$c->locs->push( 'me' );
	$c->employees( $e );
    $c->save;
}

ok( 1, 'ok' );
done_testing;
