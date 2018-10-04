use strict;
use warnings;
use Test::More;

use lib 't/lib';
use MongooseT;

{
	package Poligon;
	use Moose;
	with 'Mongoose::Document';
	has faces => is => 'rw', isa => 'Int', required => 1;

    after expanded => sub {
        my $self = shift;
        $self->faces( $self->faces + 1 );
    };
}
{
	ok ( my $p = Poligon->new( faces => 4 ), 'Create new object' );
	ok( $p->save, 'Save it' );
    is( Poligon->count, 1, 'Object was saved' );
	is( Poligon->find_one({_id => $p->_id})->faces, 5, 'expanded() is called after document is expanded into an object' );
}

done_testing;


