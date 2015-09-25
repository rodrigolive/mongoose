use strict;
use warnings;
use Test::More;
use lib 't/lib';
use MongooseT;

{
	package Person;
	use Moose;
	with 'Mongoose::Document' => {
		-collection_name => 'person_ro',
    };
	has 'name'  => ( is=>'rw', isa=>'Str', required=>1 );
	has 'email' => ( is=>'ro', isa=>'Str', required=>1 );
	has 'age'   => ( is=>'rw', isa=>'Int', default=>40 );
}

package main;
{
	my $homer = Person->new( name => "Homer Simpson", email => 'homer@springfield.tv' );
	my $id = $homer->save;
	is( ref($id), 'MongoDB::OID', 'created, id defined' );
}
{
	my $homer = Person->find_one({ name=>"Homer Simpson" });
	is( ref($homer), 'Person', 'great, object expanded even with read_only attribute' );
	is( $homer->name, 'Homer Simpson', 'homer found');
}


done_testing;
