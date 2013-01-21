package Mongoose;
use MongoDB;
our $_mongodb_client_class;
BEGIN {
    $_mongodb_client_class = $INC{'MongoDB/MongoClient.pm'}
        ? 'MongoDB::MongoClient'
        : 'MongoDB::Connection';
}
use MooseX::Singleton;
use Mongoose::Join;
use Mongoose::File;
use Mongoose::Meta::AttributeTraits;
use Moose::Util::TypeConstraints;
class_type $_mongodb_client_class;
use Carp;

has '_db' => ( is => 'rw', isa => 'HashRef[MongoDB::Database]' );

has '_connection' => (
    is  => 'rw',
    isa => $_mongodb_client_class . ' | Undef',
);

has '_args' => ( is => 'rw', isa => 'HashRef', default=>sub{{}} );

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
    $self->_args( \%p );
    return $self->connect if $now || defined wantarray;
}

sub connect {
    my $self = shift;
    my %p    = @_ || %{ $self->_args };
    my $key  = delete( $p{'-class'} ) || 'default';
    $self->_connection( $_mongodb_client_class->new(%p) )
      unless ref $self->_connection;
    $self->_db( { $key => $self->_connection->get_database( $p{db_name} ) } );
    return $self->_db->{$key};
}

sub disconnect {
    my $self = shift;
    $self->_connection and $self->_connection(undef);
}

sub connection {
    my $self = shift;
    $self->_connection and return $self->_connection;
    $self->connect and return $self->_connection;
}

sub _db_for_class {
    my ( $self, $class ) = @_;
    return $self->_db->{$class} || $self->_db->{default} if defined $self->_db;
    return $self->connect;
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

=head1 METHODS

=head2 db

Sets the current MongoDB connection and/or db name. 

    Mongoose->db( 'mydb' );

The connection defaults to whatever MongoDB defaults are
(typically localhost:27017).

For more control over the connection, C<db> takes the same parameters as
L<MongoDB::MongoClient>, plus C<db_name>. 

    my $db = Mongoose->db(
        host          => 'mongodb://localhost:27017',
        query_timeout => 60,
        db_name       => 'mydb'
    );

This will, in turn, instantiate a L<MongoDB::MongoClient> instance
with all given parameters and return a L<MongoDB::Database> object. 

B<Important>: Mongoose will always defer connecting to Mongo
until the last possible moment. This is done to prevent
using the MongoDB driver in a forked environment (ie. with a
prefork appserver like Starman, Hypnotoad or Catalyst's
HTTP::Prefork).

If you prefer to connect while setting the connection string, 
use one of these 2 options:

    Mongoose->db( db_name=>'mydb', -now=>1 );  # connect now

    # or by wating for a return value

    my $db = Mongoose->db( 'mydb' );

    # or explicitly:

    Mongoose->db( 'mydb' );
    Mongoose->connect;

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

=head1 CONTRIBUTORS

    Arthur Wolf
    Solli Moreira Honorio (shonorio)
    Michael Gentili (gentili)
    Kang-min Liu (gugod)
    Allan Whiteford (allanwhiteford)
    Kartik Thakore (kthakore)

=head1 LICENSE

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

