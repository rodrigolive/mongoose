package BankAccount;
use Moose;
with 'Document';

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

package CheckingAccount;
use Moose;
with 'Document';

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

package main;
use v5.10;
use MooseX::Mongo;
my $db = MooseX::Mongo->db( 'mediadb' );
say "DB=" . $db;
sub cleanup {
	$db->run_command({ drop => 'bankaccount' });
	$db->run_command({ drop => 'checkingaccount' });
}
cleanup();

my $savings_account = BankAccount->new( balance => 250 );
$savings_account->save;
exit;
my $checking_account = CheckingAccount->new(
      balance           => 100,
      overdraft_account => $savings_account,
);
$checking_account->save;
say BankAccount->find_one({ balance=>250 })->dump;
