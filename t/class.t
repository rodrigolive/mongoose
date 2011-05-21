use strict;
use warnings;
use Test::More;
use lib 't/lib';
use MongooseT; # this connects to the db for me
my $db = db;
$db->run_command({ drop=>'person' }); 

{
	package Person;
	use Mongoose::Class;
	with 'Mongoose::Document';

    has_one 'name' => 'Str';
    has_one 'age' => 'Num', required=>1;
}

package main;
{
	eval { my $homer = Person->new( name => "Homer Simpson" ) };
    ok $@, 'required age';
	my $homer = Person->new( name => "Homer Simpson", age=>40 );
	my $id = $homer->save;
	my $p = Person->find_one({ name=>'Homer Simpson' });
    is $p->age, 40, 'find ok'; 
}

done_testing;
