use strict;
use warnings;
use Test::More;

use Mongoose;
my $db = Mongoose->db( '_mxm_testing' );
$db->run_command({ drop=>'company' }); 
{
	package Employee;
	use Moose;
	with 'Mongoose::Document';
	has 'name' => ( is=>'rw', isa=>'Str', required=>1 );
}
{
	package Department;
	use Moose;
	use lib 'xt/author';
	use mgcoll;

	#use Moose::Util::TypeConstraints;
	with 'Mongoose::Document';
    has 'code' => ( is=>'rw', isa=>'Str');
    #has 'locs' => ( is=>'rw', isa=>'ArrayRef', metaclass=>'Array', default=>sub{[]} );
    has 'employees' => ( is=>'rw', isa=>MongooseCollection[Item] );
    #subtype 'Mongoose::Collection' => as 'Any' => where { print $_ };
}
package main;
{
    my $e = Employee->new( name=>'Bob' );
    my $c = Department->new( code=>'ACC' );
	#$c->locs->push( 'me' );
	$c->employees( $e );
    $c->save;
}

ok( 1, 'ok' );
done_testing;

