package Mongoose::Cursor;
use Moose;
use MongoDB;
extends 'MongoDB::Cursor';

has '_class' => ( is=>'rw', isa=>'Str', required=>1 );
has '_collection_name' => ( is=>'rw', isa=>'Str', required=>1 );

around 'next' => sub {
	my ($orig,$self, @args)=@_;
	my $doc = $self->$orig(@args);
	return unless defined $doc;
	my $coll_name = $self->_collection_name; 
	my $class = $self->_class;
	#eval "require " . $self->_class;
	return $class->expand( $doc );
};

around 'all' => sub {
	my ($orig,$self, @args)=@_;
	my @docs = $self->$orig(@args);

	return unless scalar @docs > 0;

	my $coll_name = $self->_collection_name; 
	my $class = $self->_class;

	return map { $class->expand( $_ ) } @docs;
};

sub each(&) {
	my $self = shift;
	my $func = shift;
	while( my $r = $self->next ) {
		last unless defined $func->( $r ) 
	}
}

=head1 NAME

Mongoose::Cursor

=head1 DESCRIPTION

Extends L<Mongoose::Cursor>. 

Wraps L<MongoDB::Cursor>'s C<next> method, so that it expands 
a document into a class.

=head1 METHODS

For your convenience:

=head2 each

Iterates over a cursor, calling your sub.

	Person->find->each( sub {
		my $obj = shift;

		# do stuff

		# return undef to break out
		return undef if $done;
	});

=cut 

1;
