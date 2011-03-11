package Mongoose::Class;
use Moose ();
use Moose::Exporter;

Moose::Exporter->setup_import_methods(
    with_meta => [ 'has_many', 'belongs_to', 'has_one','has_index' ],
    also      => 'Moose',
);

sub has_many {
    my $meta = shift;
    my $name = shift;
    my %options;

    my $isa;
    if   ( scalar @_ % 2 == 1 ) {
        $isa = shift;
    }
    %options      = @_;
    $options{isa} = $isa if $isa;
    #$options{weak_ref} = 1 unless defined $options{weak_ref};
    
    my $isa_original = $options{isa};
    if( exists $options{foreign} ){
        my $foreign = delete $options{foreign};
        $options{isa} = 'Mongoose::Join::Relational[' . $options{isa} . ']';
        $options{default} ||=
          sub {
              my $owner = shift;
              use Mongoose::Join::Relational;
              Mongoose::Join::Relational->new( with_class => "$isa_original", owner => $owner, reciprocal => $foreign );
            };        
    }else{
        $options{isa} = 'Mongoose::Join[' . $options{isa} . ']';
        $options{default} ||= sub { Mongoose::Join->new( with_class => "$isa_original" ) };
    }
    $options{is} ||= 'ro';
    $meta->add_attribute( $name, %options, );

    #So that belongs_to Any can find us
    $meta->{package}->db->{collection_to_class}->{ Mongoose->naming->( $meta->{package} ) } = $meta->{package};

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
    #$options{weak_ref} = 1 unless defined $options{weak_ref};

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
    #$options{weak_ref} = 1 unless defined $options{weak_ref};

    $meta->add_attribute( $name, %options, );
}

sub has_index {
    my $meta = shift;
    my @index;
    if( scalar @_ && ref($_[0]) ne 'HASH'  ){ @index = ({@_}); }else{@index = @_;}
    $meta->{package}->collection->ensure_index(@index);
}

=head1 NAME

Mongoose::Class - sugary Mongoose-oriented replacement for Moose

=head1 SYNOPSIS

	package MySchema::Person;
	use Mongoose::Class; # uses Moose for you
	with 'Mongoose::Document';

	has 'name' => ( is=>'rw', isa=>'Str' );
	has_many 'siblings' => ( is=>'rw', isa=>'Person' );
	belongs_to 'club' => ( is=>'rw', isa=>'Club' );
	has_one 'father' => ( is=>'rw', isa=>'Person' );

=head1 DESCRIPTION

This is very much a work-in-progress.

Basically, this module adds some sugar into your Mongoose
Document class by defining some stand-in replacements for 
Moose's own C<has>. 

	has_many
	has_one
	belongs_to

The idea: fewer keystrokes and improved readability
by self-documenting your class. 

=head1 METHODS

=head2 has_one

Does nothing. It's the same as using C<has>.

=head2 belongs_to

Does nothing. It's the same as using C<has>.

=head2 has_many

Wraps the defined relationship with another class using C<Mongoose::Join>.

This:

	has_many 'employees' => ( isa=>'Employee' );

	# or

	has_manu 'employees' => 'Employee';

Becomes this:

    has 'employees' => (
        is      => 'ro',
        isa     => 'Mongoose::Join[Employee]',
        default => sub { Mongoose::Join->new( with_class=>'Employee' ) }
    );
	
=cut

1;

