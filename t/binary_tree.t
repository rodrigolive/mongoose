use strict;
use warnings;
use Test::More;

package main;
use lib 't/lib';
use MongooseT; # this connects to the db for me
my $db = db;

$db->run_command({ drop => 'test_binary_tree' });

{
	package Test::BinaryTree;
	use Moose;
	with 'Mongoose::Document';

	  has 'node' => ( is => 'rw', isa => 'HashRef' );

	  has 'parent' => (
		  is        => 'rw',
		  isa       => 'Test::BinaryTree',
		  predicate => 'has_parent',
		  weak_ref  => 1,
	  );

	  has 'left' => (
		  is        => 'rw',
		  isa       => 'Test::BinaryTree',
		  predicate => 'has_left',
		  lazy      => 1,
		  default   => sub { Test::BinaryTree->new( parent => $_[0] ) },
		  trigger   => \&_set_parent_for_child
	  );

	  has 'right' => (
		  is        => 'rw',
		  isa       => 'Test::BinaryTree',
		  predicate => 'has_right',
		  lazy      => 1,
		  default   => sub { Test::BinaryTree->new( parent => $_[0] ) },
		  trigger   => \&_set_parent_for_child
	  );

	  sub _set_parent_for_child {
		  my ( $self, $child ) = @_;

		  confess "You cannot insert a tree which already has a parent"
			  if $child->has_parent;

		  $child->parent($self);
	  }
}

{
	my $bt = new Test::BinaryTree( node=>{ name=>'Jack', candidate=>15 } );
	my $bt2 = new Test::BinaryTree( node=>{ name=>'Sawyer', candidate=>8 } );
	my $bt3 = new Test::BinaryTree( node=>{ name=>'Kate', candidate=>4 } );
	$bt->left( $bt2 );
	$bt->right( $bt3 );
	#print $bt->dump;
	$bt->save;
}
{
	my $btc = Test::BinaryTree->collection->find_one({ node=>{ name=>'Jack', candidate=>15 } });
	ok( ref $btc eq 'HASH', 'hashref real coll' );
	my $bt = Test::BinaryTree->find_one({ node=>{ name=>'Jack', candidate=>15 } });
	ok( ref $bt->node eq 'HASH', 'hashref node inflated' ); 
	#print $bt->dump;
	is( $bt->{node}->{name}, $btc->{node}->{name}, 'data matches' );
	is( $bt->right->{node}->{name}, 'Kate', 'right node ok' );
	$bt->left->{node}->{name} = 'Hurley';
	$bt->save;
}
{
	my $bt = Test::BinaryTree->find_one({ node=>{ name=>'Jack', candidate=>15 } });
	is( $bt->left->{node}->{name}, 'Hurley', 'left node ok' );
}
{
	my $bt = Test::BinaryTree->query({ node=>{ name=>'Hurley', candidate=>8 } })->next;
	is( $bt->parent->node->{name}, 'Jack', 'parent retrieved' );	
}

done_testing;
