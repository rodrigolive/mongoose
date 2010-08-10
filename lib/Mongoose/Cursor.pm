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

1;
