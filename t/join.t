use strict;
use warnings;
use Test::More;

use Mongoose;
my $db = Mongoose->db( '_mxm_testing' );
$db->run_command({ drop=>'company' }); 
{
    package Mongoose::Collection::X;
    use Moose;
    use Moose::Util::TypeConstraints;
    subtype 'Mongoose::Collection' => as 'ArrayRef[Any]'; 
    coerce 'Mongoose::Collection[Employee]' => from 'Any' => via { die 'aaa' };
}
{
	package Department;
	use Moose;
	with 'Mongoose::Document';
    has 'code' => ( is=>'rw', isa=>'Str');
    has 'employees' => ( is=>'rw', isa=>'Mongoose::Collection[Employee]' );
    #subtype 'Mongoose::Collection' => as 'Any' => where { print $_ };
}
{
	package Employee;
	use Moose;
	with 'Mongoose::Document';
	has 'name' => ( is=>'rw', isa=>'Str', required=>1 );
}

package main;
{
    my $e = Employee->new( name=>'Bob' );
    my $c = Department->new( code=>'ACC', employees=>$e );
    $c->save;
}

ok( 1, 'ok' );
done_testing;
