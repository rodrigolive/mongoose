package Mongoose::Role::Naming;

use Moose::Role;
use Moose::Util::TypeConstraints;

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
    default => sub {$naming_template{default}}
);

1;

=head1 NAME

Mongoose::Role::Naming

=head1 DESCRIPTION

This role implement class to collection name methods for Mongoose objects.

=cut

=head2 naming

By default will compose the MongoDB collection name from your package name
by replacing double-colon C<::> with underscores C<_>, separating camel-case,
such as C<aB> with C<a_b> and uppercase with lowercase letters.

This behaviour can be changed by choosing a named method or by setting
the collection naming routine with a C<closure>.

This are the available named methods:

     named method | package name          | collection
    --------------+-----------------------+-----------------------
     short        | MyApp::Schema::FooBar | foobar
     plural       | MyApp::Schema::FooBar | foobars
     decamel      | MyApp::Schema::FooBar | foo_bar
     lower        | MyApp::Schema::FooBar | myapp::schema::author
     upper        | MyApp::Schema::FooBar | MYAPP::SCHEMA::AUTHOR
     undercolon   | MyApp::Schema::FooBar | myapp_schema_foobar
     default      | MyApp::Schema::FooBar | myapp_schema_foo_bar
     none         | MyApp::Schema::Author | MyApp::Schema::Author

You can choose a predefined naming method

    Mongoose->naming( 'plural' );

... or combine them

    Mongoose->naming( ['decamel','plural' ] );  # same as 'shorties'

If you set a closure it will receive the package name as it only parameter and
should return the collection name.

    # plain lowercase
    Mongoose->naming( sub { lc(shift) } );

