use strict;
use warnings;
use Test::More;

use lib 't/lib';
use MongooseT; # this connects to the db for me
my $db = db;

my $ret = $db->run_command({  'dropDatabase' => 1  }); 
ok( 1, 'dropped' );   # dont really care if it's dropped

done_testing;
