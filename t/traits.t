use strict;
use warnings;
use Test::More;
use DateTime;

use lib 't/lib';
use MongooseT; # this connects to the db for me
my $db = db;
$db->run_command({ drop=>'person' }); 
my $now = DateTime->now;

{
package Person;
use Moose;
with 'Mongoose::Document';

has 'name' => ( is=>'rw', isa=>'Str', required=>1, traits=>['Binary'], column=>'aaaa' );
has 'age' => ( is=>'rw', isa=>'Int', default=>40 );
has 'salary' => ( is=>'rw', isa=>'Int', traits=>['DoNotSerialize'] );
has 'date' => ( is=>'rw', isa=>'DateTime', default=>sub{$now} );
has 'date_raw' => ( is=>'rw', isa=>'DateTime', traits=>['Raw'] , default=>sub{$now} );
}

package main;
{
	my $jay = Person->new( name => "Jay", salary=>300 );
	my $id = $jay->save;
	is( ref($id), 'MongoDB::OID', 'created, id defined' );
}
{
	my $jay = Person->find_one({ name=>'Jay' });
	ok defined( $jay->age ), 'found ok';
	ok !defined( $jay->salary ), 'donotserialize';
	is ref( $jay->date ), 'DateTime', 'dt inflated';
	is ref( $jay->date_raw ), 'DateTime', 'raw inflated';
	is $jay->date->hour, $jay->date_raw->hour, 'expanded dt hour equally';
}
{
	my $jay = Person->collection->find_one({ name=>'Jay' });
	ok !defined( $jay->{salary} ), 'donotserialize mongo ok';
}

done_testing;
