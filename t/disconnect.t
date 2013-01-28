use strict;
use warnings;
use Test::More;
use lib 't/lib';
use MongooseT;

Mongoose->disconnect;
is_deeply (Mongoose->_client,{}, 'Disconnect from Mongo');

done_testing;



