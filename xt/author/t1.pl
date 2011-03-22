use v5.10;
#use MooseX::Declare;
use Moose::Autobox;
use MongoDB;
use Try::Tiny;
use DateTime;
use MooseX::Mongo;

package Person;
use Moose;
	has 'name' => ( is=>'rw', isa=>'Str', traits=>['PrimaryKey'] );
	has 'bday' => ( is=>'rw', isa=>'DateTime', default=>sub{ DateTime->now } );

package Artist;
use Moose;
extends 'Person';
with 'Document';
	has 'country' => ( is=>'rw', isa=>'Str' );
	has 'guitars' => ( is=>'rw', isa=>'ArrayRef', default=>sub{[]} );
	has 'last_cd' => ( is=>'rw', isa=>'CD', weak_ref=>1 );
	has 'age' => ( is=>'rw', isa=>'Int', default=>sub{ int rand 100 } );
	has 'temp' => ( is=>'rw', isa=>'Any', metaclass=>'DoNotMongoSerialize' );
	has 'contact' => ( is=>'rw', isa=>'ContactInfo', default=>sub{ContactInfo->new});
	sub _pk { 'name' }

package CD;
use Moose;
with 'Document';
	has 'title' => ( is=>'rw', isa=>'Str' );
	has 'artist' => ( is=>'rw', isa=>'Artist', weak_ref=>1 );
	sub _pk { 'title' }
	sub stringify {
		my $self = shift;
		$self->title . ', by ' . $self->artist->name;
	}

package ContactInfo;
use Moose;
with 'EmbeddedDocument';
	has 'phone' => ( is=>'rw', isa=>'Str', default=>'91-577-1234' );
	has 'address' => ( is=>'rw', isa=>'Str', default=>'c/ Mayor, 15' );

#-----------------------------------------------------
package main;
use Benchmark;
use Data::Dumper;

my $db = MooseX::Mongo->db( 'mediadb' );
say "DB=" . $db;
sub cleanup {
	$db->run_command({ drop => 'artist' });
	$db->run_command({ drop => 'cd' });
	$db->run_command({ drop => 'contactinfo' });
	$db->run_command({ drop => 'point' });
	$db->run_command({ drop => 'point3d' });
}
cleanup();

use Devel::LeakGuard::Object qw( leakguard );
leakguard {
	my $cds = $db->get_collection('cd');
	$cds->save({ aa=>12 });
	my $doc = $cds->find_one({ aa=>12 }) for 1..100;
};

leakguard {
	my $cd = CD->new( title=>'Entre aguas' );
	my $artist = Artist->new( name => 'Paco de Lucia', last_cd=>$cd );
	$cd->artist( $artist );

	say $artist->dump;

	say $artist->save;
	say $artist->save;
	say $artist->save;
	say $artist->dump;

	my $a2 = Artist->find_one({ name => 'Paco de Lucia' });
	say $a2->dump;

	#$a2->last_cd->title( 'Almoraima' );
	#$a2->save;
};

{
  package Point;
  use Moose;
  with 'Document';

  has 'x' => (isa => 'Int', is => 'rw', required => 1);
  has 'y' => (isa => 'Int', is => 'rw', required => 1);

  sub clear {
      my $self = shift;
      $self->x(0);
      $self->y(0);
  }

  package Point3D;
  use Moose;
  with 'Document';

  extends 'Point';

  has 'z' => (isa => 'Int', is => 'rw', required => 1);

  after 'clear' => sub {
      my $self = shift;
      $self->z(0);
  };

  package main;

  # hash or hashrefs are ok for the constructor
  my $point1 = Point->new(x => 5, y => 7);
  my $point2 = Point->new({x => 5, y => 7});
  my $point3d = Point3D->new(x => 5, y => 42, z => -5);
  $point1->save;
  $point2->save;
  $point3d->save;
}

die 'ho';
cleanup();
{
	my $cd = CD->new( title=>'Entre aguas' );
	my $artist = Artist->new( name => 'Paco de Lucia', last_cd=>$cd );
	$cd->artist( $artist );
	timethis( 1000, sub {
		$cd->save;
	});
	say $cd->_id;
}
die 'here';

my $artist = Artist->new( name => 'Paco de Lucia' );
$artist->country('Spain');
$artist->guitars->push('Hermanos Conde');
say $artist->dump;
say $artist->save;
say Artist->collection;

say 'Searching...';
my $a2;
timethis( 1000, sub {
	$a2 = Artist->find_one({ name => 'Paco de Lucia' })
	}
);;
say "Name=" . $a2->name;
say $a2->dump;

say "Cursors...";
my $cur = Artist->find({ name=>'Paco de Lucia' });
while( my $a = $cur->next ) {
	say $a->dump;
}

say 'CDs...';
my $cd = CD->new( title=>'Entre aguas' );
$a2->last_cd( $cd );
say "With cd=". $a2->dump;
$a2->save;

#Artist->insert( $artist );
#my $cd = CD->new( title=>'Almoraima', artist=>$artist );

#$db->collection('Artists')->insert( $artist );
#say "AAAAAAAAAAA=" . $artist->dump;
#say "CCCCCCCCCCC=" . $cd->dump;
#my $cds = $db->collection('CDs');
#$cds->insert( $cd ); 
#say $cd->artist->name;
#say "CD: " . $cd->stringify;
#my $favorite = $cds->find_one({ title=>'Almoraima' });
#say $favorite->dump;






