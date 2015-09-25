use strict;
use warnings;
use Test::More;
use lib 't/lib';
use MongooseT;

{
	package IntermediateRole;
	use MooseX::Role::Parameterized;
	role {
		my $p          = shift;
		my %args       = @_;
		with 'Mongoose::Document';
	};
}

{
	package MyThing;
	use Moose;
	with 'IntermediateRole';
}

package main;
my $thing=MyThing->new;
ok( $thing->save, 'Consumed by a role' );

done_testing;
