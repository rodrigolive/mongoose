use strict;
use warnings;
use Test::More;
use lib 't/lib';
use MongooseT;

subtest 'Passing params to Document role' => sub{
    {
        package Test::Person;
        use Moose;
        with 'Mongoose::Document' => {
            -collection_name => 'people',
            -as              => 'Person',
            -alias           => { 'find_one' => '_find_one' },
            -excludes        => [ 'find_one' ]
        };
        has 'name' => ( is => 'rw', isa => 'Str', required => 1 );
    }

    ok( my $homer = Test::Person->new( name => "Homer" ), 'Create new object from and aliased class' );
    ok( $homer->save, 'save it' );
    ok( my $people = db->get_collection('people'), 'Get collection as set on the role "collection_name" param' );
    is( $people->find_one({ name => 'Homer' })->{name}, 'Homer', 'Doc was created');
    ok( $homer = Person->_find_one({ name=>'Homer'}), 'aliases methods exists' );
    is( $homer->name, 'Homer', '-as alias is working');
    # this is a perl quirk - even when blessed into Person,
    #    the structure points to Test::Person
    #  try this: print bless {}, 'Person';
    is( ref($homer), 'Test::Person', 'method alias original');
    # isa, on the other hand, works fine
    ok( $homer->isa('Person'), 'isa a person' );
};

subtest 'Changing collection naming strategy' => sub{
    ok( Mongoose->naming( sub{ uc(shift) } ), 'Setting new naming convention' );

    {
        package FooPkg;
        use Moose;
        with 'Mongoose::Document';
        has 'name' => ( is=>'rw', isa=>'Str', required=>1 );
    }

    is( db->get_collection('FOOPKG')->estimated_document_count, 0, 'Test collection is empty' );
    ok( my $f = FooPkg->new( name => 'Yoyo' ), 'Create new object from a class after setting custom naming convention' );
    ok( $f->save, 'save it' );
    is( db->get_collection('FOOPKG')->estimated_document_count, 1, 'There is one object, naming strategy changed' );
};

done_testing;
