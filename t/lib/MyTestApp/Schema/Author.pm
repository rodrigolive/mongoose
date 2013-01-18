package MyTestApp::Schema::Author;
use Moose;
with 'Mongoose::Document' => { -collection_name=>'author' };

has 'name' => ( is=>'rw', isa=>'Str' );
has 'timestamp' => ( is => 'ro', isa => 'Num', default => sub { time } );

1;
