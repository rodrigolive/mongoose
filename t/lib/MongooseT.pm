use strict;
use warnings;
use Mongoose;

$ENV{MONGOOSE_SKIP} and plan skip_all => 'MONGOOSE_SKIP is set. Test skipped.';

my $db;
sub db { $db }

eval {
    my $db_name = 'mongoose_testing_'. $$;
    $db = Mongoose->db( $db_name );
    # Show database name when runner want to keep it alive
    diag("Created test database: $db_name") if $ENV{MONGOOSE_SKIP_DROP};
};
if( $@ ) {
	$ENV{MONGOOSE_SKIP} = 1;
    plan skip_all => "Could not find a local MongoDB instance to connect for testing: $@'"
}

END {
    unless ( $ENV{MONGOOSE_SKIP_DROP} ) {
        $db->drop;
    }
}

1;
