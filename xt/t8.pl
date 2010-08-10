package Person;
use Moose;
#use MooseX::Mongo::Engine::Serialize;
with 'MooseX::Mongo::Document' =>
  { pk => ['name'], };#engine => 'MooseX::Mongo::Engine::Serialize' };

has 'name' => ( is=>'rw', isa=>'Str', required=>1 );
has 'age' => ( is=>'rw', isa=>'Int', default=>40 );
has 'spouse' => ( is=>'rw', isa=>'Person' );

  package Address;
  use Moose;
  use Moose::Util::TypeConstraints;
  with 'MooseX::Mongo::EmbeddedDocument';

  use Locale::US;
  use Regexp::Common 'zip';

  my $STATES = Locale::US->new;
  subtype 'USState'
      => as Str
      => where {
             (    exists $STATES->{code2state}{ uc($_) }
               || exists $STATES->{state2code}{ uc($_) } );
         };

  subtype 'USZipCode'
      => as Value
      => where {
             /^$RE{zip}{US}{-extended => 'allow'}$/;
         };

  has 'street'   => ( is => 'rw', isa => 'Str' );
  has 'city'     => ( is => 'rw', isa => 'Str' );
  has 'state'    => ( is => 'rw', isa => 'USState' );
  has 'zip_code' => ( is => 'rw', isa => 'USZipCode' );


package main;
use v5.10;
use MooseX::Mongo;
use Benchmark;
my $db = MooseX::Mongo->db( 'mediadb' );
$db->run_command({ drop=>'person' }); 

my $o = do {
	my $homer = Person->new( name => "Homer Simpson" );
	my $marge = Person->new( name => "Marge Simpson" ); 
	$homer->spouse($marge);
	$marge->spouse($homer);
	say "pk=" . $homer->_pk;
	$homer
}->save;

my $p = Person->find_one({ name=>'Homer Simpson' });
say $p->name, $p->age;

my $homer = Person->new( name => "Homer Simpson", age=>50 );
$homer->save;

say Address->does('MooseX::Mongo::EmbeddedDocument');
