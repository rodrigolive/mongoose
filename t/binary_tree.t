use strict;
use warnings;
use Test::More;

package main;
use Mongoose;
my $db = Mongoose->db( '_mxm_testing' );
$db->run_command({ drop => 'binarytree' });

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
	my $bt2 = new Test::BinaryTree( parent=>$bt, node=>{ name=>'Sawyer', candidate=>8 } );
	my $bt3 = new Test::BinaryTree( parent=>$bt, node=>{ name=>'Kate', candidate=>4 } );
	#print $bt2->dump;
	$bt->save;
}
{
	my $btc = Test::BinaryTree->collection->find_one({ node=>{ name=>'Jack', candidate=>15 } });
	ok( ref $btc eq 'HASH', 'hashref real coll' );
	my $bt = Test::BinaryTree->find_one({ node=>{ name=>'Jack', candidate=>15 } });
	ok( ref $bt->node eq 'HASH', 'hashref node inflated' ); 
	#print $bt->dump;
}
{
	my $bt = Test::BinaryTree->query({ node=>{ name=>'Sawyer', candidate=>8 } })->next;
	is( $bt->parent->node->{name}, 'Jack', 'parent retrieved' );	
}

#$db->run_command({  'dropDatabase' => 1  }); 
done_testing;
