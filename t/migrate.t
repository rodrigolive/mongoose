use strict;
use warnings;

use Test::More;
{
  package Author;
  use Mongoose::Class;
  with 'Mongoose::Document' => { -collection_name=>'author' };
  has_one 'name' => 'Str';
}

{
  package AuthorNew;
  use Mongoose::Class;
  with 'Mongoose::Document' => { -collection_name=>'author' };
  has_one 'first_name' => 'Str';
}

use lib 't/lib';
use MongooseT;

for( 1..5 ) {
	Author->new(name=>"Jake-$_")->save;
}

Author->find->each( sub{
	my $obj = shift;
	ok defined($obj->{name}), 'created';
});


AuthorNew->find->each( sub{
	my $obj = shift;
	$obj->first_name( delete $obj->{name} );
	$obj->save;
});

Author->find->each( sub{
	my $obj = shift;
	ok !defined($obj->name), 'deleted';
	ok defined($obj->{first_name}), 'moved';
});


done_testing;
