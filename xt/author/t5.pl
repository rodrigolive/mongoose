package Request;
use Moose;
use Moose::Util::TypeConstraints;
with 'Document';

use HTTP::Headers  ();
use Params::Coerce ();
use URI            ();

subtype 'My::Types::HTTP::Headers' => as class_type('HTTP::Headers');

coerce 'My::Types::HTTP::Headers'
=> from 'ArrayRef'
=> via { HTTP::Headers->new( @{$_} ) }
=> from 'HashRef'
=> via { HTTP::Headers->new( %{$_} ) };

subtype 'My::Types::URI' => as class_type('URI');

coerce 'My::Types::URI'
=> from 'Object'
=> via { $_->isa('URI')
	? $_
		: Params::Coerce::coerce( 'URI', $_ ); }
		=> from 'Str'
		=> via { URI->new( $_, 'http' ) };

subtype 'Protocol'
=> as 'Str'
=> where { /^HTTP\/[0-9]\.[0-9]$/ };

has 'base' => ( is => 'rw', isa => 'My::Types::URI', coerce => 1 );
has 'uri'  => ( is => 'rw', isa => 'My::Types::URI', coerce => 1 );
has 'method'   => ( is => 'rw', isa => 'Str' );
has 'protocol' => ( is => 'rw', isa => 'Protocol' );
has 'headers'  => (
		is      => 'rw',
		isa     => 'My::Types::HTTP::Headers',
		coerce  => 1,
		default => sub { HTTP::Headers->new }
		);

package main;
use v5.10;
use MooseX::Mongo;
use Benchmark;
my $db = MooseX::Mongo->db( 'mediadb' );
$db->run_command({ drop=>'request' }); 
{
	my $r = new Request( base=>'http://example.com', headers=>{ "user-agent"=> 'mozilla' });
	timethis( 2000, sub {  $r->save } );
}
#$r->save;

#my $r2 = Request->find->next;
#say $r2->dump;

{
	use KiokuDB;
	use KiokuDB::Backend::MongoDB;
	
	my $conn = MongoDB::Connection->new(host => 'localhost');
	my $db = $conn->get_database('mediadb');

	my $rc = KiokuDB::Backend::MongoDB->new('collection' => $db->get_collection('request') );
	my $coll = KiokuDB->new( backend => $rc, allow_classes=>['HTTP::Headers'] );

	my $s     = $coll->new_scope;
	my $r = new Request( base=>'http://example.com', headers=>{ "user-agent"=> 'mozilla' });
	timethis( 2000, sub {  $coll->store($r) } );
}


