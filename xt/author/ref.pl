use strict;
use Mongoose;
Mongoose->db('test');

package Cat;
use Mongoose::Class;
with 'Mongoose::Document';
has_many mice  => 'Mouse';
has_one 'name' => 'Str';

package Mouse;
use Mongoose::Class;
with 'Mongoose::Document';

package main;

Cat->collection->drop;
Mouse->collection->drop;

my $cat = Cat->new( name=>'Tom');


for( 1 .. 10 ){
    my $mouse = Mouse->new();
    $cat->mice->add( $mouse );
}

$cat->save;

#is( Cat->find_one({_id => $cat->_id})->mice->find->count, 10, "added 10 mice" );

#Mouse->collection->drop;
my $k=0;
Mouse->find->each(sub{ $_[0]->delete; $k++ ; return undef if $k>5 });

#is( Cat->find_one({_id => $cat->_id})->mice->find->count, 0, "deleted 10 mice" );

#Cat->find->each(sub{ $_[0]->->save } );
#Cat->find_one->mice->fix;
Cat->find_one->fix_integrity('mice');

my $cur = Cat->collection->find;
use YAML;
while ( my $r = $cur->next ) {
	print Dump $r;
}
#done_testing();
