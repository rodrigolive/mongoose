use strict;
use warnings;

use Test::More ;

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
use Mongoose;
my $db = Mongoose->db( '_mxm_testing' ) or die $!;
$db->run_command({ drop=>'bank_account' }); 

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
	$ba1->save;
	my $r = BankAccount->find_one({ name=>'Jordi' });
	ok( !defined $r, 'overwritten' );

	my $r2 = BankAccount->find_one({ drivers_license=>'112233' });
	is( $r2->name, 'Donna', 'replaced yup' );

	my $k=0;
	BankAccount->find->each(sub{ $k++ });
	is( $k, 2, 'count ok' );
}

done_testing;

