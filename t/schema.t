use strict;
use warnings;
use Test::More;

package main;
use lib 't/lib';
use MongooseT; # connects to the db for me

my $db = db;
$db->author->drop;

Mongoose->load_schema( search_path=>'MyTestApp::Schema', shorten=>1 );

my $au = Author->new( name=>'Bob' );
$au->save;

#use YAML;
#Author->find->each( sub {
	#print Dump @_;
#});

is ref($au), 'MyTestApp::Schema::Author', 'schema found';

done_testing;
