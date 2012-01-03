use strict;
use warnings;
use Test::More;

use lib 't/lib';
use MongooseT; 
my $db = db;

$db->run_command({ drop=>'bar' }); 
$db->run_command({ drop=>'foo' }); 

package Bar;
use Moose;
with 'Mongoose::Document';
has 'stuff' => (is => 'rw', isa => 'Str', required => 1 );
1;

package Foo;
use Moose;
with 'Mongoose::Document';
has 'other_stuff' => (is => 'rw', isa => 'Str' );
has 'bars' => (is => 'rw', isa => 'Mongoose::Join[Bar]' );
1;

package main;
use Mongoose;
Mongoose->db( db_name => 'bar_foo_test' );

my $b = Bar->new( stuff => 'foo has bars' );
$b->save();

my $foo = Foo->new( other_stuff => 'sadasd' );
$foo->save();
$foo->bars( Mongoose::Join->new( with_class => "Bar" ) );
$foo->bars->add( $b );
$foo->save();
is $foo->bars->find_one->stuff => 'foo has bars', 'bars joined';

done_testing;
