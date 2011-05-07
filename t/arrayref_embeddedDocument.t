use Test::More;
{
	package Address;
	use Any::Moose;
	with 'Mongoose::EmbeddedDocument';
	has 'street' => ( is => 'rw', isa => 'Str' );

	__PACKAGE__->meta->make_immutable;
}

{
	package Person;
	use Any::Moose;
	with 'Mongoose::EmbeddedDocument';
	has 'name' => ( is => 'rw', isa => 'Str' );
	has 'address' => ( is => 'rw', isa => 'ArrayRef[Address]' );

	__PACKAGE__->meta->make_immutable;
}
{
	package Thing;
	use Any::Moose;
	with 'Mongoose::Document' => {
		-pk => ['name'],
	};

	has 'name' => (is=> 'rw', isa => 'Str') ;
	has 'tt' => (is=> 'rw' , isa => 'ArrayRef[Person]');

	__PACKAGE__->meta->make_immutable;
}

{
	package main;
	use strict;
	use lib 't/lib';
	use MongooseT;
	Thing->collection->drop;
	my $t = Thing->new( 
			name => 'test_1',
			tt   => [
				Person->new( name=>'Person 0', 
					     address=> [ Address->new( street => 'Street name 0.0'),
							 Address->new( street => 'Street name 0.1'),
							 Address->new( street => 'Street name 0.2'),
 						       ] ),
				Person->new( name=>'Person 1', 
					     address=> [ Address->new( street => 'Street name 1.0'),
							 Address->new( street => 'Street name 1.1'),
							 Address->new( street => 'Street name 1.2'),
						       ] ),
				Person->new( name=>'Person 2', 
					     address=> [ Address->new( street => 'Street name 2.0'),
							 Address->new( street => 'Street name 2.1'),
							 Address->new( street => 'Street name 2.2'),
						       ] ),
				],
	);
	
	$t->save;
	my $t2 = Thing->find_one;

	is ref($t2->tt), 'ARRAY', 'expanded array';
	is $t2->tt->[0]->name, 'Person 0', 'found Person class';
	is $t2->tt->[2]->address->[2]->street, 'Street name 2.2', 'found Address class';
}

done_testing;

