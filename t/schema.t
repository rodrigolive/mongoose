use strict;
use warnings;
use Test::More;

package main;
use lib 't/lib';
use MongooseT;

Mongoose->load_schema( search_path=>'MyTestApp::Schema', shorten=>1 );

my $au = Author->new( name=>'Bob' );
$au->save;

is ref($au), 'MyTestApp::Schema::Author', 'schema found';

my $au2 = Author->find_one( {name =>'Bob'} );
is $au->timestamp, $au2->timestamp, "roundtrip";

done_testing;
