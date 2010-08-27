package Mongoose::Class::Relational;
use Moose ();
use Moose::Exporter;

Moose::Exporter->setup_import_methods(
    with_meta => [ 'has_many', 'belongs_to', 'has_one' ],
    also      => 'Moose',
);

sub has_many {
    my $meta = shift;
    my $name = shift;
    my %options;
    if   ( scalar @_ == 1 ) { $options{isa} = shift; }
    else                    { %options      = @_; }

    my $isa_original = $options{isa};
    my $reciprocal = delete $options{reciprocal};
    $options{isa} = 'Mongoose::Join::Relational[' . $options{isa} . ']';
    $options{default} ||=
      sub {
          use lib '/home/arthur/dev/mongoose/lib/';
          use Mongoose::Join::Relational;
          Mongoose::Join::Relational->new( with_class => "$isa_original", owner => shift, reciprocal => $reciprocal  );
        };
    $options{is} ||= 'ro';
    $meta->add_attribute( $name, %options, );
}

sub belongs_to {
    my $meta = shift;
    my $name = shift;
    my %options;
    if ( scalar @_ == 1 ) {
        $options{isa} = shift;
        $options{is}  = 'rw';
    }
    else { %options = @_; }

    $meta->add_attribute( $name, %options, );
}

sub has_one {
    my $meta = shift;
    my $name = shift;
    my %options;
    if ( scalar @_ == 1 ) {
        $options{isa} = shift;
        $options{is}  = 'rw';
    }
    else { %options = @_; }

    $meta->add_attribute( $name, %options, );
}


1;

