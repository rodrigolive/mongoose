use strict;
use warnings;

use Test::More;
use Test::Fatal qw( dies_ok );
use lib 't/lib';

use MongooseT;
my $db = db;
$db->run_command({ drop => 'thingummy' });

{
    package Thingummy;
    use Moose;

    use boolean qw( true false );

    with 'Mongoose::Document';

    has 'is_sweet' => ( is => 'rw', isa => 'Bool', default => sub { true } );
    has 'has_round_edges' => ( is => 'rw', isa => 'Bool', default => sub { true } );
    has 'it_floats' => ( is => 'rw', isa => 'Bool', default => sub { false } );
}

package main;

my $thingy = Thingummy->new();
ok( my $id = $thingy->save() );

ok( my $db_thingy = $db->get_collection( 'thingummy' )->find_one( { _id => $id } ) );
is( ref( $db_thingy->{is_sweet} ), 'boolean', 'Boolean is saved properly' );
is( $db_thingy->{is_sweet}, $thingy->is_sweet() );
is( $db_thingy->{it_floats}, $thingy->it_floats() );

ok( $db_thingy = Thingummy->find_one( { _id => $id } ) );
is( ref( $db_thingy->is_sweet() ), 'boolean', 'Boolean is expanded properly' );
is( $db_thingy->is_sweet(), $thingy->is_sweet() );
is( $db_thingy->it_floats(), $thingy->it_floats() );

done_testing();
