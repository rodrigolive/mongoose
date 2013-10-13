use strict;
use warnings;
use Test::More;

use lib 't/lib';
use MongooseT; 
my $db = db;

$db->run_command({ drop=>'bar' }); 
$db->run_command({ drop=>'foo' }); 

# from RT Bug #81725
package Bar;
use Moose;
with 'Mongoose::Document';

has y => ( is => 'ro', isa => 'HashRef[ArrayRef[Foo]]' );

package Foo;
use Moose;
with 'Mongoose::EmbeddedDocument';

has val => (isa=>'Int', is=>'ro' );

package main;

my $x = Bar->new( y => { 'x.x' => [ Foo->new( val => 1234 ) ] } );
$x->save;
my $raw = $x->collection->find_one();
is $raw->{y}{'x.x'}[0]{val}, 1234, 'raw save ok';

#my $d = Bar->find_one();
#is $d->y->{xx}->[0]->{val}, 1234, 'storage ok';
#is $d->y->{xx}->[0]->val, 1234, 'perfect object from array';

done_testing;
