use strict;
use warnings;
use Test::More;

use lib 't/lib';
use MongooseT; # this connects to the db for me
my $db = db;


my $ret = $db->run_command({  'dropDatabase' => 1  }) unless $ENV{MONGOOSE_SKIP_DROP};
ok( 1, 'done' );   # dont really care if it's dropped

done_testing;
