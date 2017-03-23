use Test::More;
use boolean qw/true false/;
use DateTime;

{
    package Person;
    use Mongoose::Class;
    with 'Mongoose::Document';
    has_one 'name' => 'Str';
}

{
    package Thing;
    use Mongoose::Class;
    with 'Mongoose::Document' => { -pk => ['name'] };
    has_one 'name'       => 'Str';
    has_one 'age'        => 'Int';
    has_one 'alive'      => 'Bool';
    has_one 'alive_more' => 'ArrayRef';
    has_one 'hh'         => 'HashRef[ArrayRef]';
    has_one 'tt'         => 'HashRef[Person]';
    has_one 'arr'        => 'ArrayRef[Person]';
    has_one 'arr_int'    => 'ArrayRef[Int]';
    has 'cc' => ( is=>'rw', isa=>'CodeRef', traits=>['DoNotMongoSerialize'] );

    around 'collapse' => sub {
	    my ($orig, $self, @args ) = @_;
	    my $ret = $orig->( $self, @args );
	    return $ret;
    };
}

{
    package OtherThing;
    use Mongoose::Class;
    use boolean qw/true false/;
    with 'Mongoose::Document';
    has name    => ( is => 'ro', isa => 'Str' );
    has ready   => ( is => 'rw', isa => 'Bool',    default => sub {false} );
    has updated => ( is => 'rw', isa => 'HashRef', default => sub {{}} );
}

{
    package main;
    use strict;
    use lib 't/lib';
    use MongooseT;

    my $t = Thing->new(
	alive_more=>[55],
	tt=>{ aa=> Person->new(name=>'Bobby') },
	hh=>{ aa=> [11,22,33] },
	arr => [ Person->new(name=>'Karen' ) ],
	arr_int => [ 10, 11, 23 ],
	name    => 'Jack',
	age     => '22',
	alive   => 0,
	cc=>sub{ print 'hi!' }
    );

    ok $t->save, 'store test doc';

    ok( my $t2 = Thing->find_one({ age => 22 }), 'Int was stored as a number' );
    is ref($t2->tt), 'HASH', 'expanded hash 1';
    is ref($t2->tt->{aa}), 'Person', 'expanded hash key into class';
    is $t2->alive_more->[0], 55, 'basic arrayref resolved';
    is $t2->tt->{aa}->name, 'Bobby', 'doc $ref resolved';
    is $t2->arr->[0]->name, 'Karen', 'doc array $ref resolved';
    is $t2->arr_int->[0],  10, 'doc array $ref resolved';
    is ref($t2->hh), 'HASH', 'expanded hash 2';
    is ref($t2->hh->{aa}), 'ARRAY', 'expanded hash into array';

    subtest 'Booleans roundtip' => sub {
        ok( my $obj = OtherThing->new( name => 'Ambar' ), 'Create new object with state false (default)' );
        isa_ok( $obj->ready, 'boolean', 'State is a boolean' );
        ok( $obj->save, 'Save it' );
        ok( $obj = OtherThing->find_one($obj->_id), 'Get it back from store' );
        isa_ok( $obj->ready, 'boolean', 'State is still a boolean' );

        is( OtherThing->count({ ready => false }), 1, 'Count objects matching a boolean' );
        is( OtherThing->count({ ready => 0 }), 0, 'Count objects matching a pseudo-boolean' );
    };

    subtest 'DateTime on hashrefs roundtip' => sub {
        ok( my $obj = OtherThing->find_one, 'Get one object' );
        ok( $obj->updated({ x => DateTime->now }), 'Set a HashRef[DateTime] attribute' );
        ok( $obj->save, 'Save it' );
        ok( $obj = OtherThing->find_one($obj->_id), 'Get it back from store' );
        isa_ok( $obj->updated->{x}, 'DateTime', 'Attribute is ok' );
    };
}

done_testing;

