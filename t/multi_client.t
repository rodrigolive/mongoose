use strict;
use warnings;
use Test::More;
use Mongoose;
use lib 't/lib';

my $db = [];
eval {
    my $ts = join('_', $$, time);
    diag( "Building clients for test-stamp: $ts" );

    # use params from MONGOOSEDB if available but w/ unique db_names
    my (%p1,%p2);
    %p1 = split( /,/, $ENV{MONGOOSEDB}) if $ENV{MONGOOSEDB} ;
    %p2 = %p1;
    $p1{db_name}="multi_1_$ts";
    $p2{db_name}="multi_2_$ts";
    $p2{class}='Post';

    my $default_db = Mongoose->db( %p1 );
    my $other_db   = Mongoose->db( %p2 );
    $db = [ $default_db, $other_db ];

    Mongoose->load_schema( search_path=>'MyTestApp::Schema', shorten=>1 );
};
if ($@) {
    diag($@);
    plan skip_all => 'Could not find a MongoDB instance to connect. Set the env variable MONGOOSEDB if your instance is not default';
}
END {
    return unless @$db;
    unless ( $ENV{MONGOOSE_SKIP_DROP} ) {
        diag( "Dropping test database/s" );
        $_->drop for @$db;
    }
};

like( Author->collection->full_name, qr/^multi_1/, 'Author class use default DB/connection/client' );
like( Post->collection->full_name, qr/^multi_2/, 'Post class use not default DB/connection/client' );

ok( my $author = Author->new( name=>'Bob' ), 'Build new object from loaded class' );
is( ref($author), 'MyTestApp::Schema::Author', 'schema found' );
ok( $author->save, 'Save it!' );

{
    ok( my $au = Author->find_one({ name => 'Bob' }), 'Retrieve object from DB' );
    is( $author->timestamp, $au->timestamp, "Roundtrip" );
}

ok( my $post = Post->new( title => 'This is the title', body => 'blah blah blah!' ), 'Create new object on other class' );
ok( $post->save, 'Save new object' );
is( ref($post), 'MyTestApp::Schema::Post', 'Other class found and object created' );

done_testing;
