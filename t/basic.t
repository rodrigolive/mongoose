use strict;
use warnings;
use Test::More;
use lib 't/lib';
use MongooseT; # this connects to the db for me
my $db = db;
$db->run_command({ drop=>'person' }); 

{
	package Person;
	use Moose;
	with 'Mongoose::Document';

	has 'name' => ( is=>'rw', isa=>'Str', required=>1 );
	has 'age' => ( is=>'rw', isa=>'Int', default=>40 );
	has 'spouse' => ( is=>'rw', isa=>'Person' );
	has 'crc' => ( is=>'rw', isa=>'Str', traits=>['DoNotSerialize'], default=>'ABCD' );
}

package main;
{
	my $homer = Person->new( name => "Homer Simpson" );
	my $id = $homer->save;
	is( ref($id), 'MongoDB::OID', 'created, id defined' );
	$homer->delete;
	my $count = Person->collection->find->count;
	is( $count, 0, 'delete ok');
}
{
	my $homer = Person->new( name => "Homer Simpson" );
	my $marge = Person->new( name => "Marge Simpson" ); 
	#$homer->spouse($marge);
	$marge->spouse($homer);
    $marge->save;
	my $id = $homer->save;
	is( ref($id), 'MongoDB::OID', 'xref, id defined' );
	my $p = Person->find_one({ _id=>$id});
	is( $p->name, 'Homer Simpson', 'homer found');
}
{
	my $p = Person->find_one({ name=>'Marge Simpson' });
	ok( $p->isa('Person'), 'isa person' );
	is( $p->name, 'Marge Simpson', 'marge found');
	is( $p->spouse->name, 'Homer Simpson', 'spouse found');
}
{
    my $p = Person->find_one({ name=>'Homer Simpson' });
    my $n = $p->update('$set' => { name => 'Homer Jay Simpson'});
    is( $p->name, 'Homer Jay Simpson' , 'update works');
    $p = $p->update('$set' => { spouse => Person->find_one({ name=>'Marge Simpson' }) });
    use Data::Dumper;
    print Dumper "" , Person->find_one({ name=>'Homer Jay Simpson' });
    print Dumper "" , Person->find_one({ name=>'Marge Simpson' });
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
	my $doc = Person->collection->find->next;
	ok( !defined($doc->{crc}), 'do not serialize' );
}
{
	Person->collection->drop;
	for( 'aa', 'cc', 'bb', 'dd' ) {
		Person->new( name=>$_ )->save;
	}
	my $sorted = join ',',
		map{ $_->name } Person->query({}, { sort_by=>{ name=>1 } } )->all;
	is $sorted, 'aa,bb,cc,dd', 'sorted ok';

	my $limited = join ',',
		map{ $_->name } Person->query({}, { sort_by=>{ name=>1 }, limit=>2, skip=>2 })->all;
	is $limited, 'cc,dd', 'limited ok';
	is(Person->collection->count(), 4, 'count totals');

	my $cur = Person->query({}, { limit=>2, skip=>2 });
	is $cur->count(), 4, 'cursor total';

	my $cnt=0;
	$cur->each(sub{$cnt++});
	is $cnt,2,'each count';

	# this is failing due to a problem in mongo with sort_by
	#my $cur = Person->query({}, { sort_by=>{ name=>1 }, limit=>2, skip=>2 });
	#is $cur->count(), 4, 'cursor total';
}


done_testing;
