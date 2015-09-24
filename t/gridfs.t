use strict;
use warnings;
use Test::More;
use lib 't/lib';
use MongooseT; # this connects to the db for me
use MongoDB::GridFS;

my $db = db;
eval{ $db->run_command({ drop => 'thing' }) };

{
    package Thing;
    use Mongoose::Class;
    with 'Mongoose::Document';
    has 'file' => ( is=>'rw', isa=>'FileHandle' );
}
{
    require IO::File;
    my $fh = new IO::File "t/file/in.txt", "r";
    ok defined $fh, 'file open';
    my $t = Thing->new( file=>$fh );
    $t->save;
    $fh->close;
    ok !$t->file->isa('FileHandle'), 'not blessed yet';
    #print $t->file;
    #my $grid = db->get_gridfs;
    #print $grid->get( $t->_id );
}
sleep 1; # :-/
{
    my $t = Thing->find_one;
    ok $t->file->isa('Mongoose::File'), 'blessed ok';
    ok $t->file->isa('MongoDB::GridFS::File'), 'extended ok';
    my $data = $t->file->slurp;
    is $data, "Test file\n", 'contents ok';
    ok $t->file->drop, 'dropped';
}
{
    my $t = Thing->find_one;
    ok !defined $t->file, 'dropped';
}

done_testing;
