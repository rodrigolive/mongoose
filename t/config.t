use strict;
use warnings;
use Test::More tests => 8;

package Test::Person;
use Moose;
with 'MooseX::Mongo::Document' => { collection_name=>'people' };
has 'name' => ( is=>'rw', isa=>'Str', required=>1 );

package main;
use MooseX::Mongo;
my $db = MooseX::Mongo->db( '_mxm_testing' );

my $homer = Test::Person->new( name => "Homer" );

$db->run_command({ drop=>'people' }); 
$db->run_command({ drop=>'simpsons' }); 

#MooseX::Mongo->naming( sub{ uc(shift) } );
{
	$homer->save;
	my $people = $db->get_collection('people');
	is( $people->find_one({ name => 'Homer' })->{name}, 'Homer', 'role param collection_name'); 
}
{
	eval { $homer->collection('simpsons'); };
	ok( $@, 'error off on object collection change');
	use v5.10;
	say Test::Person->collection('simpsons')->name;
	$homer->save;
	my $people = $db->get_collection('simpsons');
	is( $people->find_one({ name => 'Homer' })->{name}, 'Homer', 'role param collection_name'); 
}
