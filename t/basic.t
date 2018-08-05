use strict;
use warnings;
use Test::More;
use lib 't/lib';
use MongooseT;

{
    package Person;
    use Moose;
    with 'Mongoose::Document';

    has 'name'   => ( is=>'rw', isa=>'Str', required=>1 );
    has 'age'    => ( is=>'rw', isa=>'Int', default=>40 );
    has 'spouse' => ( is=>'rw', isa=>'Person' );
    has 'crc'    => ( is=>'rw', isa=>'Str', traits=>['DoNotMongoSerialize'], default=>'ABCD' );
}

package main;
{
    ok( my $homer = Person->new( name => "Homer Simpson" ), 'Create homer person' );
    ok( my $id = $homer->save, 'save it' );
    is( ref($id), 'BSON::OID', 'save() returns OID' );
    is( Person->count, 1, 'collection has one doc');
    ok( $homer->delete, 'Delete it' );
    is( Person->count, 0, 'collection is empty now');
}

{
    ok( my $homer = Person->new( name => "Homer Simpson" ), 'Create homer' );
    ok( my $marge = Person->new( name => "Marge Simpson" ), 'Create marge' );
    $homer->spouse($marge);
    $marge->spouse($homer);
    my $id = $homer->save;
    is( ref($id), 'BSON::OID', 'xref, id defined' );

    is( Person->count, 2, '2 Simpsons ok' );

    Person->find->each( sub {
        my $simpson = shift;

        if ($simpson->name eq "Homer Simpson") {
            is($simpson->_id, $homer->_id, "Found Homer (iter)");
            is($simpson->spouse->_id, $marge->_id, 'Homer spouse is ok');
        }
        else {
            is($simpson->_id, $marge->_id, "Found Marge (iter)");
            is($simpson->spouse->_id, $homer->_id, 'Marge spouse is ok');
        }
    });

    ok( my $p = Person->find_one({ _id => $id }), 'find_one(HASH)' );
    is( $p->name, 'Homer Simpson', 'homer found');

    ok( $p = Person->find_one("$id"), 'find_one(STRING-OID)' );
    is( $p->name, 'Homer Simpson', 'homer found');

    ok( !Person->find_one('fail'), 'find_one(STRING-NO-OID)' );

    ok( $p = Person->find_one($id), 'find_one(BSON::OID)' );
    is( $p->name, 'Homer Simpson', 'homer found');
}

{
    my $p = Person->find_one({ name=>'Marge Simpson' });
    ok( $p->isa('Person'), 'isa person' );
    is( $p->name, 'Marge Simpson', 'marge found');
    is( $p->spouse->name, 'Homer Simpson', 'spouse found');
}
{
    my $cursor = Person->find;
    my $cnt = 0;
    while( my $p = $cursor->next ) {
	$cnt++;
    }
    is( $cnt, 2 , 'cursor works' );

    $cnt = 0;
    Person->find->each( sub {
	    $cnt++;
    });
    is( $cnt, 2 , 'each cursor works' );

    my @objs = Person->find->all;
    is( scalar(@objs), 2, 'all objs cnt ok' );
    is( ref($objs[1]), 'Person', 'blessed yup' );
}
{
    my $doc = Person->collection->find_one;
    ok( !defined($doc->{crc}), 'do not serialize' );
}
{
    Person->collection->drop;
    for( 'aa', 'cc', 'bb', 'dd' ) {
	    Person->new( name=>$_ )->save;
    }
    my $sorted = join ',', map{ $_->name } Person->find->sort({ name => 1 })->all;
    is $sorted, 'aa,bb,cc,dd', 'sorted ok';

    my $limited = join ',', map{ $_->name } Person->find->sort({ name => 1 })->skip(2)->limit(2)->all;
    is $limited, 'cc,dd', 'limited ok';
    is( Person->count, 4, 'count totals' );

    my $cur = Person->find->skip(2)->limit(2);
    is $cur->count(), 4, 'cursor count emulation counts on total';

    my $cnt = 0;
    $cur->each(sub{ $cnt++ });
    is( $cnt, 2, 'each count' );
}

{
    is( Person->count, 4, 'Count is ok before deleting' );
    ok( my $p = Person->new( name => 'Ambar' ), 'Build object' );
    ok( !$p->delete, 'Delete object before saving it does nothing' );
    is( Person->count, 4, 'Count is still ok' );
}

done_testing;
