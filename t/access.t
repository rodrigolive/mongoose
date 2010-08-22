use strict;
use warnings;
use Test::More;

use lib 't/lib';
use MongooseT; # this connects to the db for me

ok 1, 'connection ok';
db->drop;
done_testing;
