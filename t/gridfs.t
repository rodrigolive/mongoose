use strict;
use warnings;
use Test::More;
use lib 't/lib';
use MongooseT; # this connects to the db for me
use IO::File;

my $db = db;
eval{ $db->run_command({ drop => 'thing' }) };

{
    package Thing;
    use Mongoose::Class;
    with 'Mongoose::Document';
    has 'file' => ( is=>'rw', isa=>'FileHandle' );
}
{
    my $fh = new IO::File "t/file/in.txt", "r";
    ok defined $fh, 'file open';
    ok my $t = Thing->new( file => $fh ), 'Create object with file';
    ok $t->save, 'Save it';
    ok !$t->file->isa('FileHandle'), 'not blessed yet';
}
{
    is( Thing->count, 1, 'There is one doc' );
    ok my $t = Thing->find_one, 'Retrieve it';
    ok my $file = $t->file, 'Object has file';
    ok $file->isa('Mongoose::File'), 'blessed ok';
    ok $file->isa('MongoDB::GridFS::File'), 'extended ok';
    ok my $data = $t->file->slurp, 'Slurp file content';
    is $data, "Test file\n", 'contents ok';
    ok $t->file->drop, 'dropped';
}
{
    my $t = Thing->find_one;
    ok !defined $t->file, 'dropped';
}

done_testing;
