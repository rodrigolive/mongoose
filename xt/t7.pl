package Person;
use Moose;
with 'MooseX::Mongo::Document' => { pk=>['name'] };

has 'name' => ( is=>'rw', isa=>'Str', required=>1 );
has 'age' => ( is=>'rw', isa=>'Int', );
has 'spouse' => ( is=>'rw', isa=>'Person' );

package main;
use v5.10;
use MooseX::Mongo;
use Benchmark;
my $db = MooseX::Mongo->db( 'mediadb' );
$db->run_command({ drop=>'person' }); 

{
      my $o = do {  my $homer = Person->new( name => "Homer Simpson" );
        my $marge = Person->new( name => "Marge Simpson" ); 
        $homer->spouse($marge);
        $marge->spouse($homer);
		$homer };
	
	timethis( 7000, sub {  $o->save } );
}
#$r->save;

#my $r2 = Request->find->next;
#say $r2->dump;

{
	use KiokuDB;
	use KiokuDB::Backend::MongoDB;
	
	my $conn = MongoDB::Connection->new(host => 'localhost');
	my $db = $conn->get_database('mediadb');

	my $rc = KiokuDB::Backend::MongoDB->new('collection' => $db->get_collection('person') );
	my $coll = KiokuDB->new( backend => $rc, allow_classes=>['HTTP::Headers'] );

	my $s     = $coll->new_scope;
    my $homer =  do {  my $homer = Person->new( name => "Homer Simpson" );
        my $marge = Person->new( name => "Marge Simpson" ); 
        $homer->spouse($marge);
        $marge->spouse($homer);
		$homer };
	#$coll->store($homer);
	timethis( 7000, sub {  $coll->store($homer ) } );
}



