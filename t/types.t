use Test::More;

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
	has_one 'name'  => 'Str';
	has_one 'age'   => 'Int';
	has_one 'alive' => 'Bool';
	has_one 'alive_more' => 'ArrayRef';
	has_one 'hh'  => 'HashRef[ArrayRef]';
	has_one 'tt'  => 'HashRef[Person]';
    has_one 'arr' => 'ArrayRef[Person]';
    has_one 'arr_int' => 'ArrayRef[Int]';
	has 'cc' => ( is=>'rw', isa=>'CodeRef', traits=>['DoNotMongoSerialize'] );

    use Data::Dump qw/pp/;
	around 'collapse' => sub {
		my ($orig, $self, @args ) = @_;
		my $ret = $orig->( $self, @args );
        #print(pp $ret);
		return $ret;
	};
}

{
	package main;
	use strict;
    use lib 't/lib';
	use MongooseT;
	Thing->collection->drop;
	my $t = Thing->new(
        alive_more=>[55],
        tt=>{ aa=>Person->new(name=>'Bobby') },
		hh=>{ aa=>[11,22,33] },
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

}

done_testing;

