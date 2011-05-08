use strict;
use warnings;
use Test::More;

use lib 't/lib';
use MongooseT;    # this connects to the db for me
my $db = db;

$db->run_command( { drop => 'employee' } );
$db->run_command( { drop => 'department' } );
$db->run_command( { drop => 'person' } );

{

    package Department;
    use Mongoose::Class;
    with 'Mongoose::Document';
    has 'code' => ( is => 'rw', isa => 'Str' );
    has_many 'employees' => 'Employee', foreign => 'department';
}
{

    package Employee;
    use Mongoose::Class;
    with 'Mongoose::Document';
    has 'name' => ( is => 'rw', isa => 'Str', required => 1 );
    has 'salary' => ( isa => 'Int', is => 'rw', default => sub { 0 } );

    belongs_to 'department' => 'Department';
}

package main;
{
    my $dep = Department->new( code => 'ACC' );
    for ( 1 .. 15 ) {
        my $e = Employee->new( name => 'Bob' . $_ );
        $dep->employees->add( $e );
    }
    $dep->save;
}

#Query methods in document classes
{
    my $employees = Employee->resultset;
    isa_ok $employees, 'Mongoose::Resultset', 'find return';
    is $employees->count, 15, 'resultset from find has good count';
    is( Employee->resultset->search->count, 15, 'resultset from find from class has good count' );

    my @found = grep { $_ } $employees->find( salary => 0 );
    is scalar @found, 15, 'resultset in array context returns ->all';

    # rodrigo: wantarray is evil
    #@found = grep { $_ } Employee->find( salary => 0 );
    #is scalar(@found), 15, 'resultset from class in array context returns ->all';

    ok $employees->find( { name => 'Bob1' } )->count == 1, 'find on a resultset works';
    ok $employees->find( name => 'Bob1' )->count == 1, 'find on a resultset works without references';
    ok $employees->search( { name => 'Bob1' } )->count == 1, 'search on a resultset works';
    ok $employees->search( name => 'Bob1' )->count == 1, 'search on a resultset works without references';
    ok $employees->find_one( { name => 'Bob1' } )->name eq 'Bob1', 'find_one on a resultset works';
    ok $employees->single( { name => 'Bob1' } )->name eq 'Bob1', 'single on a resultset works';
    ok $employees->search( { name => 'Bob1' } )->first->name eq 'Bob1', 'first on a resultset works';
}
{
    # rodrigo: query method should not bring up resultsets
    isa_ok( Employee->query, 'Mongoose::Cursor', 'query returns a cursor') ;
    my $employees = Employee->resultset->query;  
    isa_ok $employees, 'Mongoose::Resultset', 'query return';
    is $employees->count, 15, 'resultset from query has good count';
    ok $employees->query( { name => 'Bob1' } )->count == 1, 'query on a resultset works';
}
{
    my $employee = Employee->find_one;
    isa_ok $employee, 'Employee', 'find_one return';
}
#{
#    Employee->resultset->find( name => 'Bob8' )
#        ->each( sub {
#            my $obj = shift;
#            $obj->update( { '$set' => { salary => 12 } } );
#            $obj->salary( 12 );
#            $obj->save;
#        });
#    is( Employee->find( name => 'Bob8' )->first->salary, 12, 'each works' );
#}


#Querying returns a clone
{
    my $employees = Employee->resultset->find;
    my $bob1 = $employees->query( { name => 'Bob1' } );
    ok $employees ne $bob1, 'querying returns another resultset';
}

#Update
{
    my $employee_rs = Employee->resultset->find( { name => 'Bob5' } );
    ok $employee_rs->single->name eq 'Bob5', 'find then single before update';
    $employee_rs->update( { '$inc' => { 'salary' => 1 } } );    #woo !
    is $employee_rs->single->salary, 1, 'update on resultset worked';
    $employee_rs->update_all( { '$inc' => { 'salary' => 1 } } );    #again ?! woo !
    is $employee_rs->single->salary, 2, 'update_all on resultset worked';
}

#Delete
{
    my $employee_rs = Employee->resultset->find( { salary => 2 } );
    ok $employee_rs->single->name eq 'Bob5', 'find then single before delete';
    $employee_rs->delete;                                           #oh noes !
    ok $employee_rs->count == 0, 'delete worked';
    my $other_employees = Employee->resultset->find;
    ok $other_employees->count eq 14, 'delete really worked';
    $other_employees->delete_all;                                   #oh noes !
    ok $other_employees->count == 0, 'delete worked';
    is( Employee->find->count, 0, 'delete really worked' );
}

#Find or new
{
    my $employee = Employee->resultset->find_or_new( { name => 'Tom', salary => 3 }, { key => 'name' } );
    is $employee->salary, 3, 'new employee created';
    $employee->save;
    is( Employee->resultset->count, 1, 'only one employee' );
    my $double = Employee->resultset->find_or_new( { name => 'Tom', salary => 3 }, { key => 'name' } );
    is $double->salary, 3, 'same as above';
    ok $employee->_id eq $double->_id, 'is same, not new';
    $double->save;
    is( Employee->resultset->count, 1, 'still only one employee' );
}

#New result and Create
{
    my $employee = Employee->resultset->new_result( name => 'Jane', salary => 1000000000 );    #take that, statistics !
    isa_ok $employee, 'Employee', 'jane';
    $employee->save;
    my $other_employee = Employee->resultset->create( name => 'Barbara', salary => 1000000000 );
    isa_ok $other_employee, 'Employee', 'barbara';
    is( Employee->find( { salary => 1000000000 } )->count, 2, 'two inserted' );
}

#Find or create
{
    my $employee = Employee->resultset->find_or_create( { name => 'Wally', salary => 4 }, { key => 'name' } );
    is $employee->salary, 4, 'new employee created';
    is( Employee->resultset->find( { salary => 4 } )->count, 1, 'only one employee' );
    my $double = Employee->resultset->find_or_create( { name => 'Wally', salary => 4 }, { key => 'name' } );
    is $double->salary, 4, 'same as above';
    ok $employee->_id eq $double->_id, 'is same, not new';
    $double->save;
    is( Employee->resultset->find( { salary => 4 } )->count, 1, 'still only one employee' );
}

#Find then update, or create
{
    my $employee = Employee->resultset->update_or_create( { name => 'Anna', salary => 5 }, {}, { key => 'name' } );
    is $employee->salary, 5, 'new employee created';
    is( Employee->resultset->find( { salary => 4 } )->count, 1, 'only one employee' );
    my $double = Employee->resultset->update_or_create( { name => 'Anna', salary => 6 }, {}, { key => 'name' } );
    is $double->salary, 6, 'same as above';
    ok $employee->_id eq $double->_id, 'is same, not new';
    $double->save;
    is( Employee->resultset->find({ salary => 6 })->count, 1, 'still only one employee, has good salary' );
    Employee->find->each(sub{
        warn ">" . shift->name;
    });
}

#Find then update, or new
{
    my $employee = Employee->resultset->update_or_new( { name => 'Bill', salary => 10 }, {}, { key => 'name' } );
    is $employee->salary, 10, 'new employee created';
    #ok !$employee->resultset->in_storage, 'not yet in storage';  #rodrigo: not sure what to do with in_storage
    $employee->save;

    #ok $employee->in_storage, 'now in storage'; #not yet working
    is( Employee->resultset->find( { salary => 4 } )->count, 1, 'only one employee' );
    my $double = Employee->resultset->update_or_new( { name => 'Bill', salary => 11 }, {}, { key => 'name' } );
    is $double->salary, 11, 'same as above';
    is $employee->_id, $double->_id, 'is same, not new';
    $double->save;
    is( Employee->resultset->find( { salary => 11 } )->count, 1, 'still only one employee, has good salary' );
}

done_testing;

