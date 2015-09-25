use strict;
use warnings;
use Test::More;

use lib 't/lib';
use MongooseT;

{
	package Request;
	use Moose;
	use Moose::Util::TypeConstraints;
	with 'Mongoose::Document';

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
}

package main;
{
	my $r = new Request( base=>'http://example.com', headers=>{ "user-agent"=> 'mozilla' });
	my $id = $r->save;
	is( ref($id), 'MongoDB::OID', 'id ok' );
}
{
	my $r = Request->find->next;
	is( ref($r->_id), 'MongoDB::OID', 'id ok again' );
	ok( $r->base->isa('URI::http'), 'isa uri' );
	ok( $r->headers->isa('HTTP::Headers'), 'isa uri' );
	$r->delete;
	is( Request->find->count, 0, 'nobody left');
}

done_testing;
