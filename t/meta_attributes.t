use strict;
use warnings;
use Test::More;

package Test::Person;
use Moose;
with 'Mongoose::Document' => {
    -collection_name => 'people',
    -as              => 'Person',
};
has 'name' => ( is=>'rw', isa=>'Str', required=>1 );

package main;
use lib 't/lib';
use MongooseT; # this connects to the db for me
my $db = db;

my $homer = Test::Person->new( name => "Homer" );

eval { $db->run_command({ drop=>'people' }) };
eval { $db->run_command({ drop=>'simpsons' }) };

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
	my $homer = Person->find_one({ name=>'Homer'});
	is( $homer->name, 'Homer', 'as alias working');
}
{
	Person->collection->insert({ name=>'Marge' });
	my $marge = Person->db
		->get_collection('simpsons')->find_one({ name=>'Marge' });
	is( ref($marge), 'HASH', 'as alias keeps collection change across');
}

done_testing;

