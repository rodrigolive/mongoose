use strict;
use warnings;
use Test::More tests => 8;
use YAML;
use v5.10;

use MooseX::Mongo;
my $db = MooseX::Mongo->db( '_mxm_testing' );
$db->run_command({ drop=>'person' }); 

package Person;
use Moose;
with 'MooseX::Mongo::Document';

has 'name' => ( is=>'rw', isa=>'Str', required=>1, traits=>['Binary'], column=>'aaaa' );
has 'age' => ( is=>'rw', isa=>'Int', default=>40 );
has 'salary' => ( is=>'rw', isa=>'Int', traits=>['DoNotSerialize'] );

package main;
{
	my $jay = Person->new( name => "Jay", salary=>300 );
	my $id = $jay->save;
	is( ref($id), 'MongoDB::OID', 'created, id defined' );
}
{
	my $jay = Person->collection->find_one({ name=>'Jay' });
	die "dope" unless ref $jay;
	say "DOC=" . Dump $jay;
}

