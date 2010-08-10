package BinaryTree;
use Moose;
with 'Document';

  has 'node' => ( is => 'rw', isa => 'Any' );

  has 'parent' => (
      is        => 'rw',
      isa       => 'BinaryTree',
      predicate => 'has_parent',
      weak_ref  => 1,
  );

  has 'left' => (
      is        => 'rw',
      isa       => 'BinaryTree',
      predicate => 'has_left',
      lazy      => 1,
      default   => sub { BinaryTree->new( parent => $_[0] ) },
      trigger   => \&_set_parent_for_child
  );

  has 'right' => (
      is        => 'rw',
      isa       => 'BinaryTree',
      predicate => 'has_right',
      lazy      => 1,
      default   => sub { BinaryTree->new( parent => $_[0] ) },
      trigger   => \&_set_parent_for_child
  );

  sub _set_parent_for_child {
      my ( $self, $child ) = @_;

      confess "You cannot insert a tree which already has a parent"
          if $child->has_parent;

      $child->parent($self);
  }

package main;
use v5.10;
use MooseX::Mongo;
my $db = MooseX::Mongo->db( 'mediadb' );
sub cleanup {
	$db->run_command({ drop => 'binarytree' });
}
cleanup();
{
	my $bt = new BinaryTree( node=>{ name=>'Jack', candidate=>15 } );
	my $bt2 = new BinaryTree( parent=>$bt, node=>{ name=>'Sawyer', candidate=>8 } );
	my $bt3 = new BinaryTree( parent=>$bt, node=>{ name=>'Kate', candidate=>4 } );
	$bt2->save;
}
{
	my $bt = BinaryTree->find_one({ node=>{ name=>'Jack', candidate=>15 } });
	say $bt->dump;
}
cleanup();
