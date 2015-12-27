use strict;
use warnings;
use Test::More;

use lib 't/lib';
use MongooseT;

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

ok my $x = Bar->new( y => { xx => [ Foo->new( val => 1234 ) ] } ), 'Create a doc with deep embed attribute';
ok $x->save, 'save it';
ok my $raw = $x->collection->find_one, 'Get raw object from store';
is $raw->{y}{xx}[0]{val}, 1234, 'raw is ok';

#my $d = Bar->find_one();
#is $d->y->{xx}->[0]->{val}, 1234, 'storage ok';
#is $d->y->{xx}->[0]->val, 1234, 'perfect object from array';

done_testing;
