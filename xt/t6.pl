use v5.10;
use MooseX::Mongo;

package Person;
use Moose;
with 'Document';

has 'name' => ( is=>'rw', isa=>'Str', required=>1 );

package Team;
use Moose;
with 'Document';

has 'name' => ( is=>'rw', isa=>'Str', required=>1 );
has 'cnt' => ( is=>'rw', isa=>'Int', required=>1 );
has 'members' => ( is=>'rw', isa=>'ArrayRef[Person]', default=>sub{[]} );

package main;
use Benchmark;
my $db = MooseX::Mongo->db( 'mediadb' );
$db->run_command({ drop=>'team' }); 
$db->run_command({ drop=>'person' }); 

{
	my $p = Person->new( name=>'Jack' );

	for( 1..10 ) {
		my $t = Team->new( name=>'band', members=>[$p], cnt=>$_ );
		$t->save;
	}
	my $t2 = Team->new( name=>'aaa', members=>[$p], cnt=>1 );
	$t2->save;
}
{
	my $rs = Team->query({ cnt=>{ '$lt' => "4" } }, { name=>1 });
	say $rs;
	while( my $t = $rs->first ) {
		say $t->dump;
		#$t->delete;
		#Team->delete({ name=>'band' });
	}
}
