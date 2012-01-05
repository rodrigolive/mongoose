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
    my $class_name;
    if ($args{consumer}->isa('Moose::Meta::Class'))
    {
        $class_name=$args{consumer}->name;
    }
    else
    {
        my $i=1;
        while ( my @caller = do { package DB; caller( $i++ ) } )
        {
            if ($caller[3] eq "MooseX::Role::Parameterized::Meta::Role::Parameterizable::generate_role")
            {
                my @args = @DB::args;
                my %args=@args[1..$#args];
                if ($args{'consumer'}->isa('Moose::Meta::Class'))
                {
                    $class_name=$args{'consumer'}->name;
                    last;
                }
            }
        }
    }

    die("Cannot find a class name to use") unless($class_name);

    my $collection_name = $p->{'-collection_name'} || do {
        # sanitize the class name
        Mongoose->naming->("$class_name");
    };

    # load the selected engine
    my $engine = $p->{'-engine'} || 'Mongoose::Engine::Base';
    Class::MOP::load_class($engine);

    # import the engine role into this class
    with $engine;

    # attributes
    has '_id' =>
      ( is => 'rw', isa => 'MongoDB::OID', traits => ['DoNotMongoSerialize'] );

    my $config = {
        pk              => $p->{'-pk'},
        as              => $p->{'-as'},
        collection_name => $collection_name,
    };

    #method "_mxm_config" => sub{ $config };
    $class_name->meta->{mongoose_config} = $config;

    # aliasing
    if ( my $as = $p->{'-as'} ) {
        no strict 'refs';
        *{ $as . "::" } = \*{ $class_name . "::" };
        $as->meta->{mongoose_config} = $config;
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
