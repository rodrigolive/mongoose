package AA;
use Moose;
has name => qw(isa Str is rw);

use v5.14;
use MongoDB;
;

my $connection = MongoDB::Connection->new;
my $db   = $connection->_mongoose_testing;
my $collection = $db->bar;
my $aa = AA->new( name => 'doddle' );
my $id         = $collection->insert({ ts => DateTime->now, aa=>$aa });
$collection->save;
