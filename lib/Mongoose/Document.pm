package Mongoose::Document;

use strict;
use Mongoose;
use Mongoose::Join;
use Mongoose::File;
use MooseX::Role::Parameterized;
use Mongoose::Meta::AttributeTraits;

parameter '-engine' => ( isa => 'Mongoose::Role::Engine', );
parameter '-collection_name' => ( isa => 'Str', );
parameter '-pk' => ( isa => 'ArrayRef[Str]', );
parameter '-as' => ( isa => 'Str', );

role {
    my $p    = shift;
    my %args = @_;
    my $class_name;
    if ( $args{consumer}->isa('Moose::Meta::Class') ) {
        $class_name = $args{consumer}->name;
    }
    else {
        # If we get into this block of code, it means that Mongoose was consumed
        # not by a class but by another (intermediate) role. Mongoose needs to
        # know the original class for various reasons (naming the collection
        # name being the most obvious one but not the only one).
        # What follows is an ugly hack to climb back up the consumption hierarchy
        # to find out the name of the class which was originally used. If anyone
        # can do it differently than it has to be better than the below!
        #                                              -- Allan Whiteford
        my $i=1;
        while ( my @caller = do { package
                DB; caller( $i++ ) } )
        {
            if ( $caller[3] eq 'MooseX::Role::Parameterized::Meta::Trait::Parameterizable::generate_role' ) {
                my @args = @DB::args;
                my %args = @args[1..$#args];
                if ($args{'consumer'}->isa('Moose::Meta::Class')) {
                    $class_name = $args{'consumer'}->name;
                    last;
                }
            }
        }
    }

    die("Cannot find a class name to use") unless($class_name);

    my $collection_name = $p->{'-collection_name'} || do{ Mongoose->naming->("$class_name") };

    # load the selected engine and consume it
    with( $p->{'-engine'} || 'Mongoose::Engine' );

    # attributes
    has '_id' => ( is => 'rw', isa => 'BSON::OID', traits => ['DoNotMongoSerialize'] );

    # aliasing
    if ( my $as = $p->{'-as'} ) {
        no strict 'refs';
        *{ $as . "::" } = \*{ $class_name . "::" };
        Mongoose->aliased( $as => $class_name );
    }

    # Store this class config on mongoose
    Mongoose->class_config( $class_name => {
        pk              => $p->{'-pk'},
        as              => $p->{'-as'},
        collection_name => $collection_name,
    });
};

=head1 NAME

Mongoose::Document - a Mongoose document role

=head1 SYNOPSIS

    package Person;
    use Moose;
    with 'Mongoose::Document';
    has 'name' => ( is => 'rw', isa => 'Str', required => 1 );

=head1 SEE ALSO

Read the Mongoose L<intro|Mongoose::Intro> or L<cookbook|Mongoose::Cookbook>.

=cut

1;
