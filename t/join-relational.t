use strict;
use warnings;
use Test::More;

use lib 't/lib';
use MongooseT; # this connects to the db for me
my $db = db;

$db->run_command({ drop=>'employee' }); 
$db->run_command({ drop=>'department' }); 
$db->run_command({ drop=>'person' }); 

{
	package Department;
	use Mongoose::Class::Relational;
	with 'Mongoose::Document';
    has 'code' => ( is=>'rw', isa=>'Str');
    has_many 'employees' => ( is=>'rw', isa=>'Employee', reciprocal => 'department' );
}
{
	package Employee;
	use Moose;
    use Mongoose::Class::Relational;
	with 'Mongoose::Document';
	has 'name' => ( is=>'rw', isa=>'Str', required=>1 );
    belongs_to 'department' => ( is=>'rw', isa=>'Department' );
}

{
	package Person;
	use Mongoose::Class::Relational;
	with 'Mongoose::Document';
	has 'name' => ( is=>'rw', isa=>'Str', required=>1 );
	belongs_to 'department' => ( is=>'rw', isa=>'Department', );
}
{
	package Article;
	use Mongoose::Class::Relational;
	with 'Mongoose::Document';
	has 'title' => ( is=>'rw', isa=>'Str', required=>1 );
	has_many 'authors' => ( is=>'rw', isa=>'Author', reciprocal => 'articles' );
}
{
	package Author;
	use Mongoose::Class::Relational;
    with 'Mongoose::Document';
	has 'name' => ( is=>'rw', isa=>'Str', required=>1 );
	has_many 'articles' => ( is=>'rw', isa=>'Article', reciprocal => 'authors' );
}
{
	package Authorship;
	use Mongoose::Class::Relational;
    with 'Mongoose::Document';
	has_one 'author' => 'Author';
	has_many 'articles' => ( is=>'rw', isa=>'Article', reciprocal => 'authors' );
}
package main;
{
    my $c = Department->new( code=>'ACC' );

	for( 1..15 ) {
		my $e = Employee->new( name=>'Bob' . $_ );
		$c->employees->add( $e );
	}
	$c->save;
}

{
	my $dep = Department->find_one({code=>'ACC'});
	my $cur = $dep->employees->find;
	is $cur->count, 15, 'joined ok';
	while( my $r = $cur->next ) {
		#print "FOUND: " . $r;
	}
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
	$author->save;
	is $author->articles->find->count, 0, 'count after remove ok';
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
}
{
	my $article = Article->find_one({ title=>'on foo' });
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
	has_many balls => 'Ball';
	has_many mice  => 'Mouse';

}
{
	package Ball;
	use Mongoose::Class;
	with 'Mongoose::Document';
	belongs_to cat => 'Cat'; # funky circularity

}
{
	package Mouse;
	use Mongoose::Class;
	with 'Mongoose::Document';

}
{
	Cat->collection->drop;
	Mouse->collection->drop;
	Ball->collection->drop;

	my $cat = Cat->new();
	$cat->save;

	for( 1 .. 10 ){
		my $ball = Ball->new( cat => $cat );
		$cat->balls->add( $ball );
	}

	for( 1 .. 10 ){
		my $mouse = Mouse->new();
		$cat->mice->add( $mouse );
	}

	$cat->save;

	is( Cat->find_one({_id => $cat->_id})->balls->find->count, 10, "added 10 balls" );
	is( Cat->find_one({_id => $cat->_id})->mice->find->count, 10, "added 10 mice" ); 

}

done_testing;


