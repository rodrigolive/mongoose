use strict;
use warnings;
use Test::More;

{
	package Person;
	use Moose;
	with 'Mongoose::Document';
	has 'address' => ( is=>'rw', isa=>'Address' );
}

{
	package Address;
	use Moose;
	with 'Mongoose::EmbeddedDocument';
	use namespace::autoclean;
}

package main;
is( Person->does('Mongoose::Document'), 1, 'does doc' );
is( Person->does('Mongoose::EmbeddedDocument'), 0, 'does not emb doc' );
is( Address->does('Mongoose::Document'), 1, 'does doc too' );
is( Address->does('Mongoose::EmbeddedDocument'), 1, 'does embdoc' );

done_testing;
