use strict;
use warnings;
use Test::More tests => 8;

package Test::Person;
use Moose;
with 'Mongoose::Document' => {
    -collection_name => 'people',
    -as              => 'Person',
    -alias=>{ 'find_one' => '_find_one' },
	-excludes=>['find_one'] 
};
has 'name' => ( is=>'rw', isa=>'Str', required=>1 );

package main;
use Mongoose;
my $db = Mongoose->db( '_mxm_testing' );

my $homer = Test::Person->new( name => "Homer" );

$db->run_command({ drop=>'people' }); 
$db->run_command({ drop=>'simpsons' }); 

#Mongoose->naming( sub{ uc(shift) } );
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
	is( ref($marge), 'Person', 'method alias ok');
}
{
	my $marge = Test::Person->_find_one({ name=>'Marge' });
	is( ref($marge), 'Test::Person', 'package as alias consistent');
}

$db->run_command({  'dropDatabase' => 1  }); 
