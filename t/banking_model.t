use strict;
use warnings;
use Test::More;

# -------- define classes
{
	package BankAccount;
	use Moose;
	with 'Mongoose::Document';

	  has 'balance' => ( isa => 'Int', is => 'rw', default => 0 );

	  sub deposit {
		  my ( $self, $amount ) = @_;
		  $self->balance( $self->balance + $amount );
	  }

	  sub withdraw {
		  my ( $self, $amount ) = @_;
		  my $current_balance = $self->balance();
		  ( $current_balance >= $amount )
			  || confess "Account overdrawn";
		  $self->balance( $current_balance - $amount );
	  }
}
{
	package CheckingAccount;
	use Moose;
	with 'Mongoose::Document';

	  extends 'BankAccount';

	  has 'overdraft_account' => ( isa => 'BankAccount', is => 'rw' );

	  before 'withdraw' => sub {
		  my ( $self, $amount ) = @_;
		  my $overdraft_amount = $amount - $self->balance();
		  if ( $self->overdraft_account && $overdraft_amount > 0 ) {
			  $self->overdraft_account->withdraw($overdraft_amount);
			  $self->deposit($overdraft_amount);
		  }
	  };
}
# ---------- run tests
package main;
use lib 't/lib';
use MongooseT; # connects to the db for me

my $db = db;
for my $coll (qw/ bank_account checking_account /) {
    eval{ $db->run_command({ drop => $coll }) };
}

{
	my $savings_account = BankAccount->new( balance => 250 );
	$savings_account->save;

	my $checking_account = CheckingAccount->new(
		  balance           => 100,
		  overdraft_account => $savings_account,
	);
	$checking_account->save;
}
{
	my $ba = BankAccount->collection->find_one({ balance=>250 });
	ok( ref $ba, 'found coll ba' );
	my $b = BankAccount->find_one({ balance=>250 });
	ok( ref $b, 'found ba' );
	ok( $b->isa('BankAccount'), 'blessed ba' );
}
{
	my $b = CheckingAccount->find_one({ balance=>100 });
	ok( $b->isa('CheckingAccount'), 'blessed ca' );
	ok( $b->overdraft_account->isa('BankAccount'), 'rel blessed' );
	is( $b->overdraft_account->balance, 250, 'rel balance ok' );
}
{
	my $coll = CheckingAccount->collection;
	ok( my $account = $coll->find->next, 'Get from collection' );
    if ( Mongoose->_mongodb_v1 ) {
        isa_ok( my $ba = $account->{overdraft_account}, 'MongoDB::DBRef' );
        is( ref($ba->id), 'MongoDB::OID', 'foreign key stored' );
	    is( $ba->ref, 'bank_account', 'make sure its foreign' );
    }
    else {
        ok( my $ba = $account->{overdraft_account} );
        is( ref($ba->{'$id'}), 'MongoDB::OID', 'foreign key stored' );
	    is( $ba->{'$ref'}, 'bank_account', 'make sure its foreign' );
    }

}

done_testing;
