use strict;
use warnings;
use Test::More tests => 4;

package Person;
use Moose;
with 'MooseX::Mongo::Document';

package Address;
use Moose;
with 'MooseX::Mongo::EmbeddedDocument';

package main;
is( Person->does('MooseX::Mongo::Document'), 1, 'does doc' );
is( Person->does('MooseX::Mongo::EmbeddedDocument'), 0, 'does not emb doc' );
is( Address->does('MooseX::Mongo::Document'), 1, 'does doc too' );
is( Address->does('MooseX::Mongo::EmbeddedDocument'), 1, 'does embdoc' );
