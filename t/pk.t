use strict;
use warnings;

use Test::More ;
use Test::Fatal;

{
	package BankAccount;
	use Moose;
	with 'Mongoose::Document' => {
		-pk    => [qw/ drivers_license /]
	};
	has 'name' => is=>'rw', isa=>'Str';
	has 'drivers_license' => (is=>'rw', isa=>'Int' );
}

package main;
use lib 't/lib';
use MongooseT; # this connects to the db for me
my $db = db;

$db->run_command({ drop=>'bank_account' }); 
BankAccount->collection->ensure_index( { "drivers_license" => 1 }, { unique => 1 } );

{
	my $ba1 = BankAccount->new( name=>'Jordi', drivers_license=>'112233' ); 
	my $ba2 = BankAccount->new( name=>'Gala', drivers_license=>'556677' ); 
	$ba1->save;
	$ba2->save;
	my $k=0;
	BankAccount->find->each(sub{ $k++ });
	is( $k, 2, 'inserted ok' );
}
{
	my $ba1 = BankAccount->new( name=>'Donna', drivers_license=>'112233' ); 
	like(
	    exception { $ba1->save },
	    qr/duplicate key/,
	    "saving a duplicate PK fails"
	);

	my $r2 = BankAccount->find_one({ drivers_license=>'112233' });
	is( $r2->name, 'Jordi', 'original record still correct' );

	my $k=0;
	BankAccount->find->each(sub{ $k++ });
	is( $k, 2, 'count ok' );
}

done_testing;

