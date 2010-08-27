use strict;

package Cat;
use Mongoose::Class;
with 'Mongoose::Document';
use lib '/home/arthur/dev/mongoose/lib/';
use Mongoose::Join::Relational;
has 'balls' => ( is => 'ro', isa => 'Mongoose::Join::Relational', default => sub { Mongoose::Join::Relational->new( with_class=>'Ball', owner => shift, child_reciprocal => 'cat' ) } );


package Ball;
use Mongoose::Class;
with 'Mongoose::Document';
belongs_to cat => 'Cat';


package main;

use Test::More;
use lib '/home/arthur/dev/svn/libs'; use_ok('DB');

Cat->collection->remove;
Ball->collection->remove;

my $cat = Cat->new();

$cat->balls->add( Ball->new( cat => $cat ) );

for( 1 .. 2 ){
    my $ball = Ball->new();
    $cat->balls->add( $ball ); #We don't have to specify the owner of the ball, the join does that
}

$cat->save; #Won't work unless we add elsif( $class->isa('Mongoose::Join') or $class->isa('My::Join')  ) { in Mongoose/Engine/Base.pm

is( $cat->balls->find->count, 3, "added 3 balls" );

done_testing();
