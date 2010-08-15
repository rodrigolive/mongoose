use strict;
use warnings;
use Test::More;

{
	package Test::Person;
	use Moose;
	with 'Mongoose::Document' => {
		-collection_name => 'people',
		-as              => 'Person',
		-alias=>{ 'find_one' => '_find_one' },
		-excludes=>['find_one'] 
	};
	has 'name' => ( is=>'rw', isa=>'Str', required=>1 );
}

package main;
use Mongoose;
my $db = Mongoose->db( '_mxm_testing' ) or die $!;

my $homer = Test::Person->new( name => "Homer" );

$db->run_command({ drop=>'people' }); 
$db->run_command({ drop=>'simpsons' }); 

{
	$homer->save;
	my $people = $db->get_collection('people');
	is( $people->find_one({ name => 'Homer' })->{name}, 'Homer', 'role param collection_name'); 
}
{
	eval { $homer->collection('simpsons'); };
	ok( $@, 'error off on object collection change');
	is( Test::Person->collection('simpsons')->name, 'simpsons', 'guaranteed coll name change' );
	$homer->save;
	my $people = $db->get_collection('simpsons');
	is( $people->find_one({ name => 'Homer' })->{name}, 'Homer', 'role param collection_name'); 
}
{
	my $homer = Person->_find_one({ name=>'Homer'});
	is( $homer->name, 'Homer', 'as alias working');
}
{
	Person->collection->insert({ name=>'Marge' });
	my $marge = Person->db
		->get_collection('simpsons')->find_one({ name=>'Marge' });
	is( ref($marge), 'HASH', 'as alias keeps collection change across');
}
{
	my $marge = Person->_find_one({ name=>'Marge' });
	# this is a perl quirk - even when blessed into Person,
	#    the structure points to Test::Person
	#  try this: print bless {}, 'Person';
	is( ref($marge), 'Test::Person', 'method alias original');
	# isa, on the other hand, works fine
	ok( $marge->isa('Person'), 'isa a person' );
}
{
	my $marge = Test::Person->_find_one({ name=>'Marge' });
	is( ref($marge), 'Test::Person', 'package as alias consistent');
}

#Mongoose->naming( sub{ uc(shift) } );

$db->run_command({  'dropDatabase' => 1  }); 
done_testing;
