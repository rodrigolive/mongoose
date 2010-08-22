use strict;
use warnings;
use Test::More;
use v5.10;

sub x::pp { use YAML; print Dump(@_) . "\n" }

use Mongoose;
my $db = Mongoose->db( '_mxm_testing' );
$db->run_command({ drop=>'employee' }); 
$db->run_command({ drop=>'department' }); 
$db->run_command({ drop=>'person' }); 

{
	package Department;
	use Mongoose::Class;
	with 'Mongoose::Document';
    has 'code' => ( is=>'rw', isa=>'Str');
    #has 'locs' => ( is=>'rw', isa=>'ArrayRef', metaclass=>'Array', default=>sub{[]} );
    has_many 'employees' => ( is=>'rw', isa=>'Employee',  );
}
{
	package Employee;
	use Moose;
	with 'Mongoose::Document';
	has 'name' => ( is=>'rw', isa=>'Str', required=>1 );
}

{
	package Person;
	use Mongoose::Class;
	with 'Mongoose::Document';
	has 'name' => ( is=>'rw', isa=>'Str', required=>1 );
	belongs_to 'department' => ( is=>'rw', isa=>'Department', );
}
{
	package Article;
	use Mongoose::Class;
	with 'Mongoose::Document';
	has 'title' => ( is=>'rw', isa=>'Str', required=>1 );
	has_many 'authors' => 'Author'; 
}
{
	package Author;
	use Mongoose::Class; with 'Mongoose::Document';
	has 'name' => ( is=>'rw', isa=>'Str', required=>1 );
	has_many 'articles' => 'Article'; 
}
{
	package Authorship;
	use Mongoose::Class; with 'Mongoose::Document';
	has_one 'author' => 'Author';
	has_many 'articles' => 'Article';
}
package main;
{
    my $c = Department->new( code=>'ACC' );
	#$c->locs->push( 'me' );
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
	my $article = Article->find_one({ title=>'on foo' });
	my $q1 = $article->authors->query({ name=>'Jack' });
	is $q1->count, 1, 'join query';
	is ref( $q1->next ), 'Author', 'join query ref';
	my $q2 = $article->authors->query({ name=>'Jack' }, { limit=>1, skip=>1 });
	is $q2->next, undef, 'join skipped query';
}

done_testing;

