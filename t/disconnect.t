use strict;
use warnings;
use Test::More;
use lib 't/lib';
use MongooseT;

Mongoose->disconnect;
is (Mongoose->_connection,undef, 'Disconnect from Mongo');

done_testing;



