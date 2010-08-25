package Mongoose;
use MongoDB;
use MooseX::Singleton;
use Mongoose::Join;
use Mongoose::Meta::AttributeTraits;
use Carp;

has '_db' => ( is => 'rw', isa => 'HashRef[MongoDB::Database]' );

has 'connection' => (
    is  => 'rw',
    isa => 'MongoDB::Connection',
);
has 'naming' => (
    is      => 'rw',
    isa     => 'CodeRef',
    default => sub {
        sub {
            my $n = shift;
            $n =~ s{([a-z])([A-Z])}{$1_$2}g;
            $n =~ s{\:\:}{_}g;
            lc($n);
          }
    }
);

sub db {
    my $self = shift;
    my $key  = 'default';
    if ( scalar(@_) == 1 && defined $_[0] ) {
        $self->connection( MongoDB::Connection->new );
        $self->_db( { $key => $self->connection->get_database( $_[0] ) } );
    }
    elsif ( scalar(@_) > 2 ) {
        my %p = @_;
        $key = delete( $p{class} ) || $key;
        $self->connection( MongoDB::Connection->new(@_) )
          unless ref $self->connection;
        $self->_db(
            { $key => $self->connection->get_database( $p{db_name} ) } );
    }
    return $self->_db->{default};
}

sub _db_for_class {
    my ( $self, $class ) = @_;
    return $self->_db->{$class} || $self->_db->{default};
}

sub load_schema {
    my ( $self, %args ) = @_;
    require Module::Pluggable;
    my $shorten = delete $args{shorten};
    Module::Pluggable->import( search_path => $args{search_path} );
    for my $module ( $self->plugins ) {
        eval "require $module";
        croak $@ if $@;
        if ( $shorten && $module =~ m/Schema\:\:(.*?)$/ ) {
            my $short_name = $1;
            no strict 'refs';
            *{ $short_name . "::" } = \*{ $module . "::" };
            $short_name->meta->{mongoose_config} =
              $module->meta->{mongoose_config};
        }
    }
}

1;

=head1 NAME

Mongoose - MongoDB document to Moose object mapper

=head1 SYNOPSIS

    package Person;
    use Moose;
    with 'Mongoose::Document';
    has 'name' => ( is => 'rw', isa => 'Str' );

    package main;
    use Mongoose;

    Mongoose->db('mydb');
    my $person = Person->new( name => 'Jack' );
    $person->save;

    my $person = Person->find_one( { name => 'Jack' } );
    say $person->name;    # Jack

    my $cursor = Person->find( { name => 'Jack' } );
    die "Not found" unless defined $cursor;
    while ( my $person = $cursor->next ) {
        say "You're " . $person->name;
    }

    $person->delete;

=head1 DESCRIPTION

This is a L<MongoDB> to L<Moose> object mapper. This module allows you to use the full
power of MongoDB within your Moose classes, without sacrificing MongoDB's
power, flexibility and speed.

It's loosely inspired by Ruby's MongoMapper,
which is in turn loosely based on the ActiveRecord pattern. 

Start by reading the introduction L<Mongoose::Intro>. 

Or proceed directly to the L<Mongoose::Cookbook> for many day-to-day recipes.

=begin html

<img src="http://cpansearch.perl.org/src/RODRIGO/Mongoose-0.01/etc/mongoose_icon.png" />

=end html

=head1 METHODS

=head2 db

Sets the current MongoDB connection and/or db name. 

	Mongoose->db( 'myappdb' );

The connection defaults to whatever MongoDB defaults are
(typically localhost:27017).

For more control over the connection, C<db> takes the same parameters as
L<MongoDB::Connection>, plus C<db_name>. 

    my $db = Mongoose->db(
        host          => 'mongodb://localhost:27017',
        query_timeout => 60,
        db_name       => 'myapp'
    );

This will, in turn, instantiate a L<MongoDB::Connection> instance
with all given parameters and return a L<MongoDB::Database> object. 

=head2 load_schema

Uses L<Module::Pluggable> to C<require> all modules under a given search path
or search dir.

All arguments will be sent to Module::Pluggable's C<import>, except for 
Mongoose specific ones. 

	package main;
	use Mongoose;

	# to load a schema from a namespace path:
	Mongoose->load_schema( search_path=>'MyApp::Schema' );


This method can be used to shorten class names, aliasing them for
convenience if you wish:

	Mongoose->load_schema( search_path=>'MyApp::Schema', shorten=>1 );

Will shorten the module name to it's last bit:

	MyApp::Schema::Author->new( ... );

	# becomes

	Author->new( ... );

=head2 naming 

By default, Mongoose composes the Mongo collection name from your package name 
by replacing double-colon C<::> with underscores C<_>, separating camel-case,
such as C<aB> with C<a_b> and uppercase with lowercase letters. 

This method let's you change this behaviour, by setting
setting the collection naming default sub. 

The closure receives the package name as first parameter and 
should return the collection name. 

    # let me change the naming strategy
    #  for my mongo collections
    #  to plain lowercase

    Mongoose->naming( sub { lc(shift) } );

=head2 connection

Sets/returns the current connection object, of class L<MongoDB::Connection>.

Defaults to whatever MongoDB defaults.

=head1 REPOSITORY

Fork me on github: L<http://github.com/rodrigolive/mongoose>

=head1 BUGS

This is a WIP, barely *beta* quality software. 

Report bugs via RT. Send me test cases.

=head1 TODO

* Better error control

* Finish-up multiple database support

* Allow query->fields to control which fields get expanded into the object. 

* Cleanup internals.

* More tests and use cases.

* Better documentation.

=head1 SEE ALSO

L<KiokuDB>

=head1 AUTHOR

	Rodrigo de Oliveira (rodrigolive), C<rodrigolive@gmail.com>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

