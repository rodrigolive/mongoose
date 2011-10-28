package Mongoose::Class;
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
    $options{isa} = 'Mongoose::Join[' . $options{isa} . ']';
    $options{default} ||=
      sub { Mongoose::Join->new( with_class => "$isa_original" ) };
    $options{is} ||= 'ro';
    $meta->add_attribute( $name, %options, );
}

sub belongs_to {
    my $meta = shift;
    my $name = shift;
    my %options;
    if   ( scalar @_ == 1 ) { $options{isa} = shift; }
    else                    { %options      = @_; }
    $options{is}  ||= 'rw';
    %options = ( %options, @_ ) if @_;

    $meta->add_attribute( $name, %options );
}

sub has_one {
    my $meta = shift;
    my $name = shift;
    my %options;
    if ( @_ > 0 && @_ % 2 ) {
        $options{isa} = shift;
        $options{is}  = 'rw';
        if( @_ > 1 ) {  # allow: has_one 'att' => 'Str', required=>1;
            %options = ( %options, @_ );
        }
    }
    else {
        %options = @_;
        $options{isa} ||= 'Any';
        $options{is}  ||= 'rw';
    }

    $meta->add_attribute( $name, %options, );
}

=head1 NAME

Mongoose::Class - sugary Mongoose-oriented replacement for Moose

=head1 SYNOPSIS

    package MySchema::Person;
    use Mongoose::Class; # uses Moose for you
    with 'Mongoose::Document';

    has 'name'          => ( is => 'rw', isa => 'Str' );
    has_many 'siblings' => ( is => 'rw', isa => 'Person' );
    belongs_to 'club'   => ( is => 'rw', isa => 'Club' );
    has_one 'father'    => ( is => 'rw', isa => 'Person' );

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

Wrapper around Moose's own C<has>, but allows
for a shorter syntax:

    has_one 'name';            # isa=>'Any', is=>'rw' added
    has_one 'age' => 'Num';    # is=>'rw' added
    has_one 'age' => 'Num', default=>99;

=head2 belongs_to

It's the same as using C<has_one> from above. 
It exists to improve your code expressiveness.

=head2 has_many

Wraps the defined relationship with another class using C<Mongoose::Join>.

This:

    has_many 'employees' => ( isa=>'Employee' );

    # or

    has_many 'employees' => 'Employee';

Becomes this:

    has 'employees' => (
        is      => 'ro',
        isa     => 'Mongoose::Join[Employee]',
        default => sub { Mongoose::Join->new( with_class=>'Employee' ) }
    );
    
=cut

1;

