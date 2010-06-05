use v5.10;
package MooseX::Mongo;
use MongoDB;
use MooseX::Singleton;

has 'conn' => ( is=>'rw', isa=>'MongoDB::Connection', default=>sub{ MongoDB::Connection->new } );
has '_db' => ( is=>'rw', isa=>'MongoDB::Database' );
sub db { 
	my ($self, $db_name) = @_;
	return $db_name
		? $self->_db( __PACKAGE__->conn->get_database( $db_name ) )
		: $self->_db;
}

package Document;
use Moose::Role;
#use MooseX::Storage;
use Params::Coerce;
use Scalar::Util qw/refaddr/;
use Carp;
use List::Util qw/first/;
#with Storage;
	
	has '_id' => ( is=>'rw', isa=>'MongoDB::OID', metaclass=>'DoNotSerialize' );
	has '_last_state' => ( is=>'rw', isa=>'Str', default=>'', metaclass=>'DoNotSerialize' );

	sub _pk {}
	sub _method { 'damn' }
	sub save {
		my ($self, @from )=@_;
		my $coll = $self->collection;
		my $doc = $self->collapse( @from );
		return unless defined $doc;
		delete $doc->{_last_state};
		if( $self->_id  ) {
			#say 'save from id';
			$self->_set_state();
			return $coll->update( { _id=>$self->_id }, $doc );
		} else {
			if( $self->_pk ) {
				#say 'upsert from pk';
				my $pk = $self->primary_key_from_hash($doc);
				my $ret = $coll->update( $pk, $doc, { upsert=>1 } );
				my $_id = $coll->find_one( $pk, { _id=>1 } );
				$self->_id( $_id->{_id} );
				$self->_set_state();
				return $ret;
			} else {
				#say 'save without pk';
				$self->_set_state();
				my $id = $coll->save( $doc );
				$self->_id( $id );
				return $id; 
			}
		}
	}
	sub modified {
		my ($self)=@_;
		my $ls = $self->_last_state;
		return 1 if !defined($ls) || $ls ne $self->_get_state;
	}
	sub _get_state {
		my ($self)=@_;
		use Digest::SHA qw(sha256_hex);
		my $ls = delete $self->{_last_state};
		my $s = sha256_hex $self->dump;
		$self->_last_state( $ls ) if $ls;
		return $s;
	}
	sub _set_state {
		my ($self)=@_;
		$self->_last_state( $self->_get_state );
	}
	sub collapse {
		my ($self, @from )=@_;
		return $self
			if first { refaddr($self) == refaddr($_) } @from; #check for circularity
		my $packed = { %$self }; # clone the data 
		for my $key ( keys %$packed ) {
			my $obj = $packed->{$key};
			if( my $class =blessed $obj ) {
				#say "checking.... $class....";
				next unless $class->can('meta'); # only mooses from here on 
				if( $class->does('EmbeddedDocument') ) {
					$packed->{$key} = $obj->collapse( @from, $self ) or next;
				}
				elsif( $class->does('Document') ) {
					$obj->save( @from, $self ) if $obj->modified;
					my $id = $obj->_id;
					$packed->{$key} = { '$ref' => lc($class), '$id'=>$id };
				}
			} elsif( ref $obj eq 'ARRAY' ) {
				my @docs;
				my $aryclass;
				for( @$obj ) {
					$aryclass ||= blessed $_;
					if( $aryclass ) {
						if( $aryclass->does('EmbeddedDocument') ) {
							push @docs, $_->collapse(@from, $self);
						} else {
							$_->save( @from, $self ) if $_->modified;
							my $id = $_->_id;
							push @docs, { '$ref' => lc($aryclass), '$id'=>$id };
						}
					} else {
						push @docs, $_;
					}
				}
				$packed->{$key} = \@docs;
			}
			#say $self->meta->get_attribute('employees')->type_constraint;
		}
		return $packed;
	}
	sub collapse_raw {
		return shift;
	}
	sub collapse_pack {
		return shift->pack;
	}
	sub expand {
		my ($self,$doc,@from)=@_;
		my @later;
		my $coll_name = $self->collection_name;
		for my $attr ( $coll_name->meta->get_all_attributes ) {
			my $name = $attr->name;
			next unless exists $doc->{$name};
			my $type = $attr->type_constraint or next;
			my $class = $type->name or next;
			$class->can('meta') or next;
			if( $class->does('EmbeddedDocument') ) {
				$doc->{$name} = $class->new( $doc->{$name} ) 
			}
			elsif( $class->does('Document') ) {
				if( my $_id = delete $doc->{$name}->{'$id'} ) {
					if( my $circ_doc = first { $_->{_id} eq $_id } @from ) {
						$doc->{$name} = bless( $circ_doc , $class );
					} else {	
						$doc->{$name} = $class->find_one({ _id=>$_id }, undef, @from, $doc )
					}
				}
			}
		}
		#my $obj = $coll_name->new( $doc );
		return undef unless defined $doc;
		return bless $doc => $coll_name;
	}
	sub expand_raw {
		my ($self,$doc)=@_;
		my $coll_name = $self->collection_name;
		return bless $doc => $coll_name;
	}
	sub expand_unpack {
		my ($self,$doc)=@_;
		my $coll_name = $self->collection_name;
		return $coll_name->unpack( $doc );
	}
	sub db {
		return MooseX::Mongo->db
			or croak 'MongoDB not set. Set MooseX::Mongo->db("name") first';
	}
	sub collection {
		my ($self) = @_;
		my $db = $self->db;
		my $coll_name = $self->collection_name;
		my $coll = $db->get_collection( lc $coll_name );
	}
	sub primary_key_from_hash {
		my ($self,$hash)=@_;
		my @keys = $self->_pk;
		return { map { $_ => $self->{$_} } @keys };
	}
	sub find {
		my ($self,$p) = @_;
		my $cursor = bless $self->collection->find($p), 'Cursor';
		$cursor->_collection_name( $self->collection_name );
		return $cursor;
	}
	sub find_one {
		my ($self,$query,$fields, @from) = @_;
		my $doc = $self->collection->find_one( $query, $fields );
		return undef unless defined $doc;
		return $self->expand( $doc, @from );
	}
	sub collection_name {
		my ($self) = @_;
		ref $self || $self;
	}

package EmbeddedDocument;
use Moose::Role; 
#use MooseX::Storage;
with 'Document';
#with Storage;

package Moose::Meta::Attribute::Custom::Trait::PrimaryKey;
use Moose::Role;

package DocumentID;
use Moose;
use MooseX::Storage;
extends 'MongoDB::OID';
with Storage;

package Cursor;
use Moose;
use MongoDB;
extends 'MongoDB::Cursor';

has '_collection_name' => ( is=>'rw', isa=>'Str', required=>1 );

around 'next' => sub {
	my ($orig,$self)=@_;
	#die $self->coll_name;
	my $doc = $self->$orig;
	return unless defined $doc;
	my $coll_name = $self->_collection_name; 
	return $coll_name->expand( $doc );
};

1;

