use strict;
use warnings;
use Test::More;

use Mongoose;
my $db = Mongoose->db( '_mxm_testing' );
$db->run_command({ drop=>'person' }); 

{
	package Person;
	use Moose;
	with 'Mongoose::Document';

	has 'name' => ( is=>'rw', isa=>'Str', required=>1 );
	has 'age' => ( is=>'rw', isa=>'Int', default=>40 );
	has 'spouse' => ( is=>'rw', isa=>'Person' );
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
	$homer->spouse($marge);
	$marge->spouse($homer);
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
}

$db->run_command({  'dropDatabase' => 1  }); 

done_testing;
