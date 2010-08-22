use strict;
use warnings;
use Mongoose;

my $db;
sub db { return $db }

$ENV{MONGOOSE_SKIP} and plan skip_all => 'MONGOOSE_SKIP is set. Test skipped.';
eval {
	$db = Mongoose->db( $ENV{MONGOOSEDB} ? split( /,/, $ENV{MONGOOSEDB} ) : '_mongoose_testing' )
};
if( $@ ) {
	$ENV{MONGOOSE_SKIP} = 1;
    plan skip_all =>
	'Could not find a MongoDB instance to connect. Set the env variable MONGOOSEDB if your instance is not default';
}

1;
