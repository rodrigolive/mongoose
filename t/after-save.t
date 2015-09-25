use strict;
use warnings;
use Test::More;

use lib 't/lib';
use MongooseT;

my $ball_count = 0;
my $cat_count  = 0;

{
	package Cat;
	use Mongoose::Class;
	with 'Mongoose::Document';
	has_many balls => 'Ball';

        after 'save' => sub {
            $cat_count += 1;
        };
}
{
	package Ball;
	use Mongoose::Class;
	with 'Mongoose::Document';
	belongs_to cat => 'Cat'; # funky circularity

        after 'save' => sub {
            $ball_count += 1;
        };
}
{
	Cat->collection->drop;
	Ball->collection->drop;

	my $cat = Cat->new();
	$cat->save;
        is $cat_count,  1,  "Cat->after_save called 1 times";
        $cat_count = 0;

	for( 1 .. 10 ){
            my $ball = Ball->new( cat => $cat );
            $cat->balls->add( $ball );
	}

	$cat->save;

        is $ball_count, 10, "Ball->after_save called 10 times";
        is $cat_count,  1,  "Cat->after_save called 1 times";

	is( Cat->find_one({_id => $cat->_id})->balls->find->count, 10, "added 10 balls" );
}

done_testing;


