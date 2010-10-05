package Mongoose::Document;
use strict;
use Mongoose;
use MooseX::Role::Parameterized;
use Mongoose::Meta::AttributeTraits;

parameter '-engine' => ( isa => 'Mongoose::Role::Engine', );

parameter '-collection_name' => ( isa => 'Str', );

parameter '-pk' => ( isa => 'ArrayRef[Str]', );

parameter '-as' => ( isa => 'Str', );

role {
    my $p          = shift;
    my %args       = @_;
    my $class_name = $args{consumer}->name;

    my $collection_name = $p->{'-collection_name'} || do {
        # sanitize the class name
        Mongoose->naming->($class_name);
    };

    # load the selected engine
    my $engine = $p->{'-engine'} || 'Mongoose::Engine::Base';
    Class::MOP::load_class($engine);

    # import the engine role into this class
    with $engine;

    # attributes
    has '_id' =>
      ( is => 'rw', isa => 'MongoDB::OID', traits => ['DoNotSerialize'] );

    my $config = {
        pk              => $p->{'-pk'},
        as              => $p->{'-as'},
        collection_name => $collection_name,
    };

    #method "_mxm_config" => sub{ $config };
    $class_name->meta->{mongoose_config} = $config;

    my $meta = $class_name->meta;
    Mongoose->_db_for_class( $meta->{package} )->{collection_to_class}->{ Mongoose->naming->( $meta->{package} ) } = $meta->{package} unless $meta->{package} =~ m{^Moose::Meta};

    # aliasing
    if ( my $as = $p->{'-as'} ) {
        no strict 'refs';
        *{ $as . "::" } = \*{ $class_name . "::" };
        $as->meta->{mongoose_config} = $config;
        $meta = $as->meta;
        $meta->{package}->db->{collection_to_class}->{ Mongoose->naming->( $meta->{package} ) } = $meta->{package};
    }


};

=head1 NAME

Mongoose::Document - a Mongo document role

=head1 SYNOPSIS

	package Person;
	use Moose;
	with 'Mongoose::Document';
	has 'name' => ( is=>'rw', isa=>'Str', required=>1 );

=head1 SEE ALSO

Read the Mongoose L<Mongoose::Intro|intro> or L<Mongoose::Cookbook|cookbook>.

=cut

1;
