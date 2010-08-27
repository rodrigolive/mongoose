#!/usr/bin/perl
use Test::More;
use lib '/home/arthur/dev/svn/libs';

#Test uses
use_ok('DB');
use_ok('Test::Document');

#Clean
Test::Document->collection->remove;
#Test::Document::Dog->collection->remove;
#Test::Document::Cat->collection->remove;

my $document = Test::Document->new(number => 323);
$document->save;
ok( $document->number == 323 , 'number is 323' );

my $id = $document->_id;
ok( $id, 'has_as_id: ' . $id );


my $new_document = Test::Document->find_one({ _id => $id });
ok( $id == $new_document->_id, 'id is same: ' . $id);

my $dog = Test::Document::Dog->new(name => 'woofy', document => $document);
$document->dog($dog);
ok( $document->dog->name eq 'woofy', 'has_one');
ok( $document->dog->document->number == 323, 'belongs_to');

for my $id ( 1 .. 2 ){
    my $cat = Test::Document::Cat->new(name => "cat $id");
    $cat->save;
    $document->cats->add( $cat );
}
#$document->save;
is( $document->cats->find->count, 2, "inserted 2 cats" );

#$new_document->delete;
#my $check = Test::Document->find({ _id => $id });
#ok( ! $check->has_next, 'was deleted' );

done_testing();
