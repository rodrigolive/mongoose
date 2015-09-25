use strict;
use warnings;
use Test::More;
use lib 't/lib';
use MongooseT;

{
    package Person;
    use Moose;
    with 'Mongoose::Document';
    has 'address' => ( is => 'rw', isa => 'Address' );
    has 'name' => ( is => 'rw', isa => 'Str', required => 1 );
}
{
    package Address;
    use Moose;
    with 'Mongoose::EmbeddedDocument';
    has 'street' => is => 'rw', isa => 'Str';
}

package main;
{
    my $pers = Person->new(
        name    => "Juanita",
        address => Address->new( street => 'Elm St.' )
    );
    my $id = $pers->save;
    is( ref($id), 'MongoDB::OID', 'created, id defined' );
}
{
	my $obj = Person->find_one({ name=>'Juanita' });
	is( ref($obj->address), 'Address', 'relationship ok' );
	is( $obj->address->street, 'Elm St.', 'data ok' );
	my $doc = Person->collection->find_one({ name=>'Juanita' });
	is( $doc->{address}->{street}, 'Elm St.', 'embedded ok' );
}

done_testing;
