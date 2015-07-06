package Mongoose;

use MongoDB;
use Class::MOP;
use MooseX::Singleton;
use Mongoose::Join;
use Mongoose::File;
use Mongoose::Meta::AttributeTraits;
use Moose::Util::TypeConstraints;
use Carp;

has '_db' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub {{}},
);

has '_client' => (
    is      => 'rw',
    isa     => "HashRef",
    lazy    => 1,
    default => sub {{}},
    clearer => 'disconnect'
);

has '_args' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub{{}}
);

# naming templates
my %naming_template = (
    same       => sub { $_[0] },
    short      => sub { $_[0] =~ s{^.*\:\:(.*?)$}{$1}g; $_[0] },
    plural     => sub { $_[0] =~ s{^.*\:\:(.*?)$}{$1}g; lc "$_[0]s" },
    decamel    => sub { $_[0] =~ s{([a-z])([A-Z])}{$1_$2}g; lc $_[0] },
    undercolon => sub { $_[0] =~ s{\:\:}{_}g; lc $_[0] },
    lower      => sub { lc $_[0] },
    lc         => sub { lc $_[0] },
    upper      => sub { uc $_[0] },
    uc         => sub { uc $_[0] },
    default => sub {
        $_[0] =~ s{([a-z])([A-Z])}{$1_$2}g;
        $_[0] =~ s{\:\:}{_}g;
        lc $_[0];
    }
);
subtype 'Mongoose::CodeRef' => as 'CodeRef';
coerce 'Mongoose::CodeRef'
    => from 'Str' => via {
        my $template = $naming_template{ $_[0] }
            or die "naming template '$_[0]' not found";
        return $template;
    }
    => from 'ArrayRef' => via {
        my @filters;
        for( @{ $_[0] } ) {
            my $template = $naming_template{ $_ }
                or die "naming template '$_' not found";
            # add filter to list
            push @filters, sub {
                my $name = shift;
                return $template->($name);
            }
        }
        # now, accumulate all filters
        return sub {
            my $name = shift;
            map { $name = $_->($name) } @filters;
            return $name;
        }
    };

has 'naming' => (
    is      => 'rw',
    isa     => 'Mongoose::CodeRef',
    coerce  => 1,
    default => sub {$naming_template{default} }
);

sub db {
    my $self = shift;
    my %p    = @_ == 1 ? (db_name=>shift) : @_;
    my $now  = delete $p{'-now'};
    my $name = $self->_add_args( \%p );

    return $self->connect($name) if $now || defined wantarray;
}

# setup db config and class to db mapping if class exists.
sub _add_args {
    my ( $self, $args ) = @_;
    my $name = 'default';
    if ( my $class = delete $args->{class} ) {
        $class = [$class] unless ref $class eq 'ARRAY';
        $name  = join "-", @$class;
        $self->_args->{class}{$_} = $name for @$class;
    }
    $self->_args->{db}{$name} = $args;
    $name;
}

# Connection/db name for a given class
sub _name_for_class {
    my ( $self, $class ) = @_;
    return 'default' unless $class;
    $self->_args->{class}{$class} || 'default';
}

# Go thru class-db mapping and ensure to get a connected db.
sub _db_for_class {
    my ( $self, $class ) = @_;
    my $name = $self->_name_for_class($class);
    $self->_db->{$name} || $self->connect($name);
}

sub connect {
    my ( $self, $name ) = @_;
    $name ||= 'default';
    my %p   = %{ $self->_args->{db}{$name} };
    my $data_db_name = $p{db_name};
    my $auth_db_name = delete $p{auth_db_name} || $data_db_name;
    $p{db_name} = $auth_db_name;    # in MongoDB::Client db_name is auth db, not necessarily data db

    $self->_client->{$name} = MongoDB::MongoClient->new(%p)
      unless ref $self->_client->{$name};

    $self->_db->{$name} = $self->_client->{$name}->get_database( $data_db_name );
}

sub connection {
    my ( $self, $name ) = @_;
    $name ||= 'default';
    $self->_client->{$name} and return $self->_client->{$name};
    $self->connect($name) and return $self->_client->{$name};
}

sub load_schema {
    my ( $self, %args ) = @_;
    require Module::Pluggable;
    my $shorten = delete $args{shorten};
    my $search_path = delete $args{search_path};
    Module::Pluggable->import( search_path => $search_path );
    for my $module ( $self->plugins ) {
        eval "require $module";
        croak $@ if $@;
        if ( $shorten && $module =~ m/$search_path\:\:(.*?)$/ ) {
            my $short_name = $1;
            no strict 'refs';
            *{ $short_name . "::" } = \*{ $module . "::" };
            Class::MOP::store_metaclass_by_name( $short_name, $module->meta );
            Class::MOP::weaken_metaclass( $short_name );
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

=head1 METHODS

=head2 db

Sets the current MongoDB connection and/or db name. 

    Mongoose->db( 'mydb' );

The connection defaults to whatever MongoDB defaults are
(typically localhost:27017).

For more control over the connection, C<db> takes the same parameters as
L<MongoDB::MongoClient>, plus C<auth_db_name>. 

    my $db = Mongoose->db(
        host          => 'mongodb://somehost:27017',
        query_timeout => 60,
        db_name       => 'mydb',
        auth_db_name  => 'admin',
        username      => 'myuser',
        password      => 'mypass',
    );

This will, in turn, instantiate a L<MongoDB::MongoClient> instance after
authenticating user vs C<admin> with all given parameters, and return
a L<MongoDB::Database> object for C<mydb>.

C<auth_db_name> defaults to the value of C<db_name>.

B<Important>: Mongoose will always defer connecting to Mongo
until the last possible moment. This is done to prevent
using the MongoDB driver in a forked environment (ie. with a
prefork appserver like Starman, Hypnotoad or Catalyst's
HTTP::Prefork).

If you prefer to connect while setting the connection string, 
use one of these options:

    Mongoose->db( db_name=>'mydb', -now=>1 );  # connect now

    # or by wating for a return value

    my $db = Mongoose->db( 'mydb' );

    # or explicitly:

    Mongoose->db( 'mydb' );
    Mongoose->connect;

You can separate your classes storage on multiple hosts/databases 
by calling db() several times:

    # Default host/database (connect now!)
    my $db = Mongoose->db( 'mydb' );
    
    # Other database for some class (defer connection)
    Mongoose->db( db_name => 'my_other_db', class => 'Log' );

    # Other database on other host for several classes
    Mongoose->db( 
        db_name => 'my_remote_db', 
        host    => 'mongodb://192.168.1.23:27017',
        class   => [qw/ Author Post /]
    );

=head2 connect

Connects to Mongo using the connection arguments passed to the C<db> method.

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
the collection naming routine with a C<closure>.

The closure receives the package name as first parameter and 
should return the collection name. 

    # let me change the naming strategy
    #  for my mongo collections
    #  to plain lowercase

    Mongoose->naming( sub { lc(shift) } );

    # if you prefer, use a predefined naming template

    Mongoose->naming( 'plural' );  # my favorite

    # or combine them 

    Mongoose->naming( ['decamel','plural' ] );  # same as 'shorties'

Here are the templates available:

     template     | package name             |  collection
    --------------+--------------------------+---------------------------
     short        | MyApp::Schema::FooBar    |  foobar
     plural       | MyApp::Schema::FooBar    |  foobars
     decamel      | MyApp::Schema::FooBar    |  foo_bar
     lower        | MyApp::Schema::FooBar    |  myapp::schema::author
     upper        | MyApp::Schema::FooBar    |  MYAPP::SCHEMA::AUTHOR
     undercolon   | MyApp::Schema::FooBar    |  myapp_schema_foobar
     default      | MyApp::Schema::FooBar    |  myapp_schema_foo_bar
     none         | MyApp::Schema::Author    |  MyApp::Schema::Author

BTW, you can just use the full package name (template C<none>) as a collection 
in Mongo, as it won't complain about colons in the collection name. 

=head2 connection

Sets/returns the current connection object, of class L<MongoDB::MongoClient>.

Defaults to whatever MongoDB defaults.

=head2 disconnect

Unsets the Mongoose connection handler. 

=head1 REPOSITORY

Fork me on github: L<http://github.com/rodrigolive/mongoose>

=head1 BUGS

This is a WIP, now *beta* quality software. 

Report bugs via Github Issue reporting L<https://github.com/rodrigolive/mongoose/issues>.
Test cases highly desired and appreciated.

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

=head1 MAINTAINER

    Diego Kuperman (diegok)

=head1 CONTRIBUTORS

    Arthur Wolf
    Solli Moreira Honorio (shonorio)
    Michael Gentili (gentili)
    Kang-min Liu (gugod)
    Allan Whiteford (allanwhiteford)
    Kartik Thakore (kthakore)
    David Golden (dagolden)

=head1 LICENSE

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

