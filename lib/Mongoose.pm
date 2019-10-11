package Mongoose;

use MooseX::Singleton;
use Class::MOP;
use MongoDB;
use Carp;
use version;

with 'Mongoose::Role::Naming';

has _db => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub {{}},
);

has _client => (
    is      => 'rw',
    isa     => "HashRef",
    lazy    => 1,
    default => sub {{}},
    clearer => 'disconnect'
);

has _args => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub{{}}
);

has _alias => ( # keep track of aliased() document classes.
    is      => 'rw',
    isa     => 'HashRef',
    default => sub{{}}
);

has _config => ( # Store document classes configuration
    is      => 'rw',
    isa     => 'HashRef',
    default => sub{{}}
);

has _ns => ( # Selected namespace/tenant
    is      => 'rw',
    isa     => 'Str',
    default => sub{'default'}
);

sub namespace {
    my $self = shift;
    if ( my $name = shift ) { $self->_ns($name) }
    $self->_ns;
}

sub db {
    my $self = shift;
    my %p    = @_ == 1 ? (db_name=>shift) : @_;
    my $now  = delete($p{'-now'}) || defined wantarray;
    my $name = $self->_add_args( \%p );

    return $self->connect($name) if $now;
}

sub class_config {
    my ( $self, $class_name, $config ) = @_;

    # Set
    return $self->_config->{$class_name} = $config if $config;

    # Get
    my $class = $self->aliased(ref $class_name || $class_name);
    confess "Document class '$class' is not registered. Registered classes are: ".
            join(', ', keys %{$self->_config}) unless exists $self->_config->{$class};
    $self->_config->{$class};
}

# setup db config and class to db mapping if class exists.
sub _add_args {
    my ( $self, $args ) = @_;
    my $name = 'default';
    my $ns   = delete $args->{namespace} || $self->_ns;
    $ns      = [$ns] unless ref $ns eq 'ARRAY';

    if ( my $class = delete $args->{class} ) {
        $class = [$class] unless ref $class eq 'ARRAY';
        $name  = join "-", @$class;
        $self->_args->{class}{$_} = $name for @$class;
    }

    # Keep track of config for every namespace
    $self->_args->{db}{$_}{$name} = $args for @$ns;

    $name;
}

# Connection/db name for a given class
sub _name_for_class {
    my ( $self, $class ) = @_;
    return 'default' unless $class;
    $self->_args->{class}{$self->aliased($class)} || 'default';
}

# Go thru class-db mapping and ensure to get a connected db.
sub connection {
    my ( $self, $class ) = @_;
    my $name = $self->_name_for_class($class);
    $self->_db->{$self->_ns}{$name} || $self->connect($name);
}

sub connect {
    my ( $self, $name ) = @_;
    $name ||= 'default';
    my $ns  = $self->_ns;

    confess "Namespace `$ns` is not defined" unless $self->_args->{db}{$ns};

    # Ensure we have a config for $ns and $name or fallback to defaults
    unless ( exists $self->_args->{db}{$ns}{$name} ) {
        if    ( exists $self->_args->{db}{$ns}{default} ) { $name = 'default' }
        elsif ( exists $self->_args->{db}{default}{$name} ) { $ns = 'default' }
        else { ($ns, $name) = ('default', 'default')  }
    }

    my %conf    = %{ $self->_args->{db}{$ns}{$name} };
    my $db_name = delete $conf{db_name};
    my $client  = $self->_get_client(%conf);

    $self->_db->{$ns}{$name} = $client->get_database( $db_name );
}

sub _get_client {
    my ( $self, %conf ) = @_;
    $conf{host} ||= 'mongodb://localhost:27017';
    $self->_client->{$conf{host}} ||= MongoDB::MongoClient->new(%conf);
}

sub load_schema {
    my ( $self, %args ) = @_;
    my $shorten     = delete $args{shorten};
    my $search_path = delete $args{search_path};

    require Module::Pluggable;
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
            $self->aliased($short_name => $module);
        }
    }

    # Resolve class names on configured database per loaded class
    if ( $shorten && ( my $class_map = $self->_args->{class} ) ) {
        for ( keys %$class_map ) {
            $class_map->{$self->aliased($_)} = delete $class_map->{$_};
        }
    }

    $self;
}

sub aliased {
    my ( $self, $alias, $class ) = @_;
    $self->_alias->{$alias} = $class if $class;
    exists $self->_alias->{$alias} ? $self->_alias->{$alias} : $alias;
}

__PACKAGE__->meta->make_immutable();

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

    $person = Person->find_one({ name => 'Jack' });
    say $person->name; # Jack

    Person->find({ name => qr/^J/' })->each(sub{
        say "Found ", $person->name;
    });

    $person->delete;

=head1 DESCRIPTION

This is a L<MongoDB> to L<Moose> object mapper. This module allows you to use the full
power of MongoDB within your Moose classes, without sacrificing MongoDB's
power, flexibility and speed.

It's loosely inspired by Ruby's MongoMapper,
which is in turn loosely based on the ActiveRecord pattern.

Start by reading the introduction L<Mongoose::Intro>.

Or proceed directly to the L<Mongoose::Cookbook> for many day-to-day recipes.

=head1 WARNING

Since version 2.00 Mongoose only support the new L<MongoDB> driver v2.x.x which it's now required.

Please let me know if you find anything strange using this new driver.

=head1 METHODS

=head2 db

Sets the current MongoDB connection and/or db name.

    Mongoose->db( 'mydb' );

The connection defaults to whatever MongoDB defaults are
(typically localhost:27017).

For more control over the connection, C<db> takes the same parameters as
L<MongoDB::MongoClient>.

    my $db = Mongoose->db(
        host           => 'mongodb://somehost:27017',
        read_pref_mode => 'secondaryPreferred',
        db_name        => 'mydb',
        username       => 'myuser',
        password       => 'mypass',
        ssl            => 1
    );

This will, in turn, instantiate a L<MongoDB::MongoClient> and return
a L<MongoDB::Database> object for C<mydb>.

B<Important>: Mongoose will always defer connecting to Mongo
until the last possible moment. This is done to prevent
using the MongoDB driver in a forked environment (ie. with a
prefork appserver like Starman, Hypnotoad or Catalyst's
HTTP::Prefork).

If you prefer to connect while setting the connection string,
use one of these options:

    Mongoose->db( db_name=>'mydb', -now=>1 );  # connect now

    # or by waiting for a return value

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

There is one more level of abstraction called C<namespace> so you can implement multitenant schemas,
with that you can map different database configuration to your clases and your schema will select
the ones corresponding to the current C<namespace>. In most of the use cases it will just defalt to
the "default" namespace.

    # Default host/database for all loaded classes
    Mongoose->db( 'mydb' );

    # Other database for some classes on a different namespace
    Mongoose->db(
        db_name   => 'other_db',
        class     => [qw/ Category Post /],
        namespace => 'blog_b'
    );

=head2 connect

Connects to Mongo using the connection arguments passed to the C<db> method.

=head2 connection

Returns a connection to the database for the provided class name or the default
connection when no class name is provided.

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

=head2 disconnect

Unsets the Mongoose connection handler/s.

=head2 namespace

The current namespace. You will use this in case your schema db's are configured using namespaces as described in C<db>.
You can switch the namespace by setting it like:

   Mongoose->namespace('my_namespace');

It defauls to the "default" namespace.

=head2 class_config

Keep track of document classes config solving aliasing indirection.

=head2 aliased

Keep track of aliasing classes. Useful to retrieve full document class from a shortened one.

=head1 COLLECTION NAMING

By default, Mongoose composes the Mongo collection name from your package name
by replacing double-colon C<::> with underscores C<_>, separating camel-case,
such as C<aB> with C<a_b> and uppercase with lowercase letters.

This behaviour can be changed by choosing other named method or by setting
the collection naming routine with a C<closure> as explained in L<Mongoose::Role::Naming>.

=head1 REPOSITORY

Fork me on github: L<http://github.com/rodrigolive/mongoose>

=head1 BUGS

This is a WIP. Please report bugs via Github Issue reporting L<https://github.com/rodrigolive/mongoose/issues>.
Test cases highly desired and appreciated.

=head1 TODO

* Better error control

* Allow query->fields to control which fields get expanded into the object.

* Better documentation.

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
    Mohammad S Anwar (manwar)

=head1 LICENSE

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

