use strict;
use warnings;
use Test::More;
use DateTime;

use lib 't/lib';
use MongooseT;

{
    package Person;
    use Moose;
    with 'Mongoose::Document';

    my $now = DateTime->now;

    has 'name'     => ( is=>'rw', isa=>'Str', required=>1, traits=>['Binary'], column=>'aaaa' );
    has 'age'      => ( is=>'rw', isa=>'Int', default=>40 );
    has 'salary'   => ( is=>'rw', isa=>'Int', traits=>['DoNotMongoSerialize'] );
    has 'date'     => ( is=>'rw', isa=>'DateTime', default=>sub{$now} );
    has 'date_raw' => ( is=>'rw', default => sub{$now} );
}

package main;
{
	my $jay = Person->new( name => "Jay", salary=>300 );
	isa_ok( $jay->save, 'BSON::OID', 'created, id defined' );
}
{
	my $jay = Person->find_one({ name=>'Jay' });
	ok defined( $jay->age ), 'found ok';
	ok !defined( $jay->salary ), 'donotserialize';
	isa_ok $jay->date, 'DateTime', 'Type DateTime was inflated';
	isa_ok $jay->date_raw, 'BSON::Time', 'Native time is stored as BSON::Time';
	is $jay->date->hour, $jay->date_raw->as_datetime->hour, 'expanded dt hour equally';
}
{
	my $jay = Person->collection->find_one({ name=>'Jay' });
	ok !defined( $jay->{salary} ), 'donotserialize mongo ok';
}

done_testing;
