package MyTestApp::Schema::Post;
use Moose;
with 'Mongoose::Document' => { -collection_name=>'post' };

has 'title' => ( is=>'rw', isa=>'Str' );
has 'body'  => ( is=>'rw', isa=>'Str' );

1;
