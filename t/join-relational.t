use strict;
use warnings;
use Test::More;
use Data::Dumper;

use lib 't/lib';
use MongooseT; # this connects to the db for me
my $db = db;

$db->run_command({ drop=>'employee' }); 
$db->run_command({ drop=>'department' }); 
$db->run_command({ drop=>'person' }); 


package Department;
use Mongoose::Class;
with 'Mongoose::Document';
has 'code' => ( is=>'rw', isa=>'Str');
has_many 'employees' => 'Employee', foreign => 'department';

package Employee;
use Moose;
use Mongoose::Class;
with 'Mongoose::Document';
has 'name' => ( is=>'rw', isa=>'Str', required=>1 );
belongs_to 'department' => 'Department';

package Person;
use Mongoose::Class;
with 'Mongoose::Document';
has 'name' => ( is=>'rw', isa=>'Str', required=>1 );
belongs_to 'department' => 'Department';

package Article;
use Mongoose::Class;
with 'Mongoose::Document';
has 'title' => ( is=>'rw', isa=>'Str', required=>1 );
has_many 'authors' => 'Author', foreign => 'articles';

package Author;
use Mongoose::Class;
with 'Mongoose::Document';
has 'name' => ( is=>'rw', isa=>'Str', required=>1 );
has_many 'articles' => 'Article', foreign => 'authors';

package Authorship;
use Mongoose::Class;
with 'Mongoose::Document';
has_one 'author' => 'Author';
has_many 'articles' => 'Article', foreign => 'authors';

package main;

my $c = Department->new( code=>'ACC' );

for( 1..15 ) {
    my $e = Employee->new( name=>'Bob' . $_ );
    $c->employees->add( $e );
}
$c->save;



my $dep = Department->find_one({code=>'ACC'});
my $cur = $dep->employees->find;
is $cur->count, 15, 'joined ok';
while( my $r = $cur->next ) {
    #print "FOUND: " . $r;
}

{
	my $dep = Department->new({code=>'Devel'});
	my $per = Person->new( name=>'Mary', department=>$dep );
	$per->save;
}
{
	my $per = Person->find_one({ name=>'Mary' });
	is $per->department->code, 'Devel', 'belongs to ok';
}
{
    use Data::Dumper;
	Article->collection->drop;
	Author->collection->drop;
	my $ar = Article->new( title=>'on foo' );
	my $au = Author->new( name=>'Jack' );
	$ar->authors->add( $au );
	$au->articles->add( $ar );
	$au->save;


	my $authorship = Authorship->new;
	$authorship->author( $au );
	$authorship->articles->add( Article->new(title=>'Eneida') );
	$authorship->articles->add( Article->new(title=>'Ulisses') );
}
{
	my $article = Article->find_one({ title=>'on foo' });
	is $article->authors->find({ name=>'Jack' })->count, 1, 'join find';
	is $article->authors->find({ name=>'Unknown' })->count, 0, 'join find not';
}
{
	Article->collection->drop;
	Author->collection->drop;
	my $ar = Article->new( title=>'on foo' );
	my $au = Author->new( name=>'Jack' );
	$ar->authors->add( $au );
	$au->articles->add( $ar );
    
	$au->save;

    my $author = Author->find_one;
    my $first_article = $author->articles->find_one;
	ok $first_article->isa('Article'), 'find_one on join';
	is $author->articles->find->count, 1, 'count ok';
    $author->articles->remove( $first_article );
    is $author->articles->find->count, 1, 'count after remove but before save ok';
	$author->save;
	is $author->articles->find->count, 0, 'count after remove and save ok';
}

{
    my $author = Author->find_one;
	my $article = Article->new(title=>'OnMoney'); 
	$author->articles->add( $article );
	$author->save;
	$author->articles->add( $article );
	$author->articles->add( $article );
	my $buffer = $author->articles->buffer;
	is scalar(keys(%{$author->articles->buffer})), 1, 'buffer is not empty';
	$author->save;
	$author->save;
	is scalar(keys(%{$author->articles->buffer})), 0, 'buffer is flushed after save';
	is $author->articles->find->count, 1, 'count ok';
    is scalar $author->articles->find->all, 1, 'all ok';
}
{
	my $article = Article->find_one({ title=>'OnMoney' });
    is $article->authors->find({ name=>'Jack' })->count, 1, 'count ok';
	my $q1 = $article->authors->query({ name=>'Jack' });
	is $q1->count, 1, 'join query';

	is ref( $q1->next ), 'Author', 'join query ref';
	my $q2 = $article->authors->query({ name=>'Jack' }, { limit=>1, skip=>1 });
	is $q2->next, undef, 'join skipped query';

}
{
	package Cat;
	use Mongoose::Class;
	with 'Mongoose::Document';
	has_many balls => 'Ball', foreign => 'cat';
	has_many mice  => 'Mouse', foreign => 'cat';

}
{
	package Ball;
	use Mongoose::Class;
	with 'Mongoose::Document';
	belongs_to cat => 'Cat'; # funky circularity
    has number => ( isa => 'Num' , is => 'rw' );

}
{
	package Mouse;
	use Mongoose::Class;
	with 'Mongoose::Document';
	belongs_to cat => 'Cat'; # funky circularity
    has number => ( isa => 'Num' , is => 'rw' );

}
{
	Cat->collection->drop;
	Mouse->collection->drop;
	Ball->collection->drop;

	my $cat = Cat->new();
	$cat->save;

	for( 1 .. 10 ){
		my $ball = Ball->new( cat => $cat, number => $_ );
		$cat->balls->add( $ball );
	}

	for( 1 .. 10 ){
		my $mouse = Mouse->new( number => $_ );
		$cat->mice->add( $mouse );
	}

	$cat->save;

	is( Cat->find_one({_id => $cat->_id})->balls->find->count, 10, "added 10 balls" );
	is( Cat->find_one({_id => $cat->_id})->mice->find->count, 10, "added 10 mice" );

    ok 1, 'dbix class like methods';

    #find_or_new
    $cat = Cat->find_one({_id => $cat->_id});
    my $mouse = $cat->mice->find_or_new({ number => 11 }, { key => 'number' });
    is $cat->mice->count, 10, 'still 10 mice after find_or_new';
    $mouse->save;
    is $cat->mice->count, 11, '11 mice after find_or_new and save';
    $mouse = $cat->balls->find_or_new({ number => 11 }, { key => 'number' });
    $mouse->save;
    is $cat->mice->count, 11, 'still 11 mice after double find_or_new and save';

    #find_or_create
    is $cat->mice->count, 11, 'still 11 mice before find_or_create';
    $mouse = $cat->mice->find_or_create({ number => 12 }, { key => 'number' });
    is $cat->mice->count, 12, '12 mice after find_or_create';
    $mouse = $cat->balls->find_or_new({ number => 12 }, { key => 'number' });
    is $cat->mice->count, 12, 'still 12 mice after double find_or_create';

    #update
    $cat->balls->update({'$set' => { number => 100}});
    is $cat->balls->find( number => 100 )->count, 11, 'now 11 balls with number = 100';
    is $cat->balls->find( number => 0 )->count, 0, 'now 0 balls with number = 0';

    #update_all
    $cat->mice->update({'$set' => { number => 100}});
    is $cat->mice->find( number => 100 )->count, 12, 'now 12 mice with number = 100';
    is $cat->mice->find( number => 0 )->count, 0, 'now 0 balls with number = 0';

    #update_or_create
    $mouse = $cat->mice->update_or_create( { number => 101 } , { '$set' => {'number' => 102}  }, { key => 'number' } );
    is( Mouse->search( number => 102 )->count , 0, 'update_or_create create' );
    is( Mouse->search( number => 101 )->count , 1, 'update_or_create create' );
    my $mouse2 = $cat->mice->update_or_create( { number => 101 } , { '$set' => {'number' => 102}  }, { key => 'number' } );
    is( Mouse->search( number => 101 )->count , 0, 'update_or_create update' );
    is( Mouse->search( number => 102 )->count , 1, 'update_or_create update' );
    is $mouse->_id , $mouse2->_id, 'returned the same object';

    #update_or_new
    $mouse = $cat->mice->update_or_new( { number => 201 } , { '$set' => {'number' => 202}  }, { key => 'number' } );
    $mouse->save;
    is( Mouse->search( number => 202 )->count , 0, 'update_or_new new but not update' );
    is( Mouse->search( number => 201 )->count , 1, 'update_or_new new' );
    $mouse2 = $cat->mice->update_or_new( { number => 201 } , { '$set' => {'number' => 202}  }, { key => 'number' } );
    $mouse2->save;
    is( Mouse->search( number => 201 )->count , 0, 'update_or_new did update' );
    is( Mouse->search( number => 202 )->count , 1, 'update_or_create did update but not create' );
    is $mouse->_id , $mouse2->_id, 'returned the same object';

    #Remove for objects
    is $cat->mice->count, 14, 'before delete the join way';
    is scalar $cat->mice->all, 14, 'before delete';
    $cat->mice->remove( $cat->mice->all );
    $cat->save;
    is $cat->mice->count, 0, 'deleted mice with a list of objects';

    #Remove the same way resultsets does
    is $cat->balls->count, 12, 'before delete the resultset way';
    is scalar $cat->balls->all, 12, 'before delete';
    $cat->balls->search({number => 12})->remove;
    is $cat->balls->count, 11, 'deleted one with delete';
    $cat->balls->remove_all({});
    is $cat->balls->count, 0, 'deleted balls with delete_all';

    #Each
    $cat->balls->create( number => 10 );
    is $cat->balls->search( number => 10 )->count, 1, 'create works by the way ...';
    $cat->balls->each(sub{ shift->delete; });
    is $cat->balls->search( number => 10 )->count, 0, 'each works';
    
    

}

done_testing;


