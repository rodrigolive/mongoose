use strict;
use warnings;
use Test::More;

package main;
use lib 't/lib';
use MongooseT;

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
	ok( my $bt  = new Test::BinaryTree( node=>{ name=>'Jack', candidate=>15 } ), 'Create first node' );
	ok( my $bt2 = new Test::BinaryTree( node=>{ name=>'Sawyer', candidate=>8 } ), 'Create second node' );
	ok( my $bt3 = new Test::BinaryTree( node=>{ name=>'Kate', candidate=>4 } ), 'Create third node' );
	$bt->left( $bt2 );
	$bt->right( $bt3 );
	$bt->save;
}

{
	ok( my $btc = Test::BinaryTree->collection->find_one({ 'node.name'=>'Jack', 'node.candidate'=>15 }), 'Get first from real collection' );
	ok( ref $btc eq 'HASH', 'hashref real collection' );
	ok( my $bt = Test::BinaryTree->find_one({ 'node.name'=>'Jack', 'node.candidate'=>15 }), 'Get it from schema' );
	ok( ref $bt->node eq 'HASH', 'hashref node inflated' );
    #print $bt->dump;
	is( $bt->{node}->{name}, $btc->{node}->{name}, 'data matches' );
	is( $bt->right->{node}->{name}, 'Kate', 'right node ok' );
	$bt->left->{node}->{name} = 'Hurley';
	$bt->save;
}

{
	ok( my $bt = Test::BinaryTree->find_one({ 'node.name'=>'Jack', 'node.candidate'=>15 }), 'Retrieve node' );
	is( $bt->left->{node}->{name}, 'Hurley', 'left node ok' );
}

{
	ok( my $bt = Test::BinaryTree->query({ 'node.name'=>'Hurley', 'node.candidate'=>8 })->next, 'Retrive parent node querying schema' );
	is( $bt->parent->node->{name}, 'Jack', 'parent retrieved' );
}

done_testing;
