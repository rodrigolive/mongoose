use v5.10;
package Mongoose;
use MongoDB;
use MooseX::Singleton;
use Mongoose::Meta::AttributeTraits;

has '_db' => ( is => 'rw', isa => 'MongoDB::Database' );
has 'connection' => (
    is      => 'rw',
    isa     => 'MongoDB::Connection',
    default => sub { MongoDB::Connection->new }
);
has 'naming' => (
    is      => 'rw',
    isa     => 'CodeRef',
    default => sub {
        sub {
			my $n=shift;
			$n =~ s{([a-z])([A-Z])}{$1_$2}g;
			$n =~ s{\:\:}{_}g;
			lc($n);
		}
    }
);

sub db { 
	my ($self, $db_name) = @_;
	return $db_name
		? $self->_db( __PACKAGE__->connection->get_database( $db_name ) )
		: $self->_db;
}


1;

=head1 SYNOPSIS

	package Person;
	with 'Mongoose::Document';
	has 'name' => ( is=>'rw', isa=>'Str' );

	package main;
	use Mongoose;

	my $person = Person->new( name=>'Jack' );
	$person->save;

	my $person = Person->find_one({ name=>'Jack' });

	my $cursor = Person->find({ name=>'Jack' });
	die "Not found" unless defined $cursor;
	while( my $person = $cursor->next ) {
		say "You're " . $person->name;	
	}

=head1 DESCRIPTION

This is a MongoDB-Moose object mapper. This module allows you to use the full
power of MongoDB with your Moose objects, without sacrificing MongoDB's
power, flexibility and speed.

It's loosely inspired by Ruby's MongoMapper,
which is in turn based on the ActiveRecord pattern. 

Start by reading the introduction. 

Then proceed to the tutorial.

And look for quick ready to go recipies in the Cookbook.

=head1 METHODS


=head1 TODO

* Allow query->fields to control which fields get expanded into the object. 
* Cleanup internals.
