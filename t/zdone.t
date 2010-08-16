use strict;
use warnings;
use Test::More;

use Mongoose;
my $db = Mongoose->db( '_mxm_testing' );
my $ret = $db->run_command({  'dropDatabase' => 1  }); 
ok( 1, 'dropped' );   # dont really care if it's dropped

done_testing;
