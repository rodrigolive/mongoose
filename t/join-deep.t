use strict;
use warnings;
use Test::More;

use lib 't/lib';
use MongooseT;

package Artist;
use Mongoose::Class; with 'Mongoose::Document';

has_one name => 'Str';
has_many cds => 'CD';

package CD;
use Mongoose::Class; with 'Mongoose::Document';

has_one title   => 'Str';
has_many tracks => 'Track';
belongs_to artist  => 'Artist';

package Track;
use Mongoose::Class; with 'Mongoose::Document';

has_one title => 'Str';
has_one num => 'Int';
has_many musicians => 'Musician';
belongs_to cd => 'CD';

package Musician;
use Mongoose::Class; with 'Mongoose::Document';

has_one name => 'Str';

package main;

{
    my $a = Artist->new( name=>'Bruce' );
    my $cd = CD->new( title=>'USA' );
    my $tr = Track->new( title=>'track1' );
    my $mus = Musician->new( name=>'Roy' );

    $tr->musicians->add( $mus );
    $cd->tracks->add( $tr );
    $a->cds->add( $cd );
    $a->save;
}
{
    my $a = Artist->find_one;
    my @cds = $a->cds->all;
    my @tracks = $cds[0]->tracks->all;
    my @mus = $tracks[0]->musicians->all;
    is $mus[0]->name, 'Roy', 'deep join';
}

{
    my $a = Artist->find_one;
    is $a->cds->first->tracks->first->musicians->first->name, 'Roy', 'first method';
}
{
    my $a = Artist->find_one;
    my $cd = CD->new( title=>'Human' );
    $a->cds->add( $cd );
    $a->save;
}
{
    my $cd = CD->find_one({ title=>'USA' });
    my $tr = Track->new( title=>'Fire' );
    $tr->cd( $cd );
    $tr->save;
    $cd->tracks->add( $tr );
    $cd->save;
}
{
    my @cds = CD->find->all;
    is scalar(@cds), 2, 'count ok';
}
{
    my $tr = Track->find_one({ title=>'Fire' });
    ok defined $tr, 'found ok';
    my $cd = $tr->cd;
    is $cd->title, 'USA', 'found one cd';
}
{
    my %cds = CD->find->hash_on('title');
    ok exists $cds{'USA'}, 'hashed on';
    is ref( $cds{'USA'} ), 'CD', 'hashed on value';
}
{
    my %cds = CD->find->hash_array('title');
    ok exists $cds{'USA'}, 'hashed array';
    is ref( $cds{'USA'} ), 'ARRAY', 'hashed array isa array';
    is $cds{USA}[0]->title, 'USA', 'object in array';

    my $cd = $cds{USA}[0];
    my %fires = $cd->tracks->hash_on('title', { title=> qr/Fi/ } );
    is ref $fires{Fire}, 'Track', 'hash_on find track from Join';
    %fires = $cd->tracks->find({ title=>qr/Fi/ })->hash_on('title');
    is ref $fires{Fire}, 'Track', 'hash_on find track from Cursor';
}

done_testing;
