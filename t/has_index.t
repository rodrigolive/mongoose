use strict;
use warnings;
use Test::More;
use Data::Dumper;
use Devel::Cycle;

use lib 't/lib';
use MongooseT; # this connects to the db for me
my $db = db;

$db->run_command({ drop=>'department' }); 

package Department;
use Mongoose::Class;
with 'Mongoose::Document';
has 'code' => ( is=>'rw', isa=>'Str');
has_index { code => 1 };
has_index code => -1 ;

package main;

my $c = Department->new( code=>'ACC' );

my @indexes = $c->collection->get_indexes;

is( $indexes[1]->{key}->{code}, 1, 'index ok' );

is( $indexes[2]->{key}->{code}, -1, 'index ok' );





done_testing;
1;
