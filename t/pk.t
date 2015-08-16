use strict;
use warnings;

use Test::More ;
use Test::Fatal;

{
	package BankAccount;
	use Moose;
	with 'Mongoose::Document' => { -pk => [qw/ drivers_license /] };
	has 'name' => is=>'rw', isa=>'Str';
	has 'drivers_license' => (is=>'rw', isa=>'Int' );
}

package main;
use lib 't/lib';
use MongooseT; # this connects to the db for me
my $db = db;

eval{ $db->run_command({ drop=>'bank_account' }) };
BankAccount->collection->ensure_index( { "drivers_license" => 1 }, { unique => 1 } );

{
	my $ba1 = BankAccount->new( name=>'Jordi', drivers_license => 112233 );
	my $ba2 = BankAccount->new( name=>'Gala',  drivers_license => 556677 );
	ok( $ba1->save, 'Insert first' );
	ok( $ba2->save, 'Insert second' );
	is( BankAccount->find->count, 2, 'inserted ok' );
}
{
	my $ba1 = BankAccount->new( name => 'Donna', drivers_license => 112233 );
	like(
	    exception { $ba1->save },
	    qr/duplicate key/,
	    "saving a duplicate PK fails"
	);

	ok( my $doc = BankAccount->find_one({drivers_license => 112233}), 'Retrieve original');
	is( $doc->name, 'Jordi', 'original record still correct' );
	is( BankAccount->find->count, 2, 'count ok' );
}

done_testing;

