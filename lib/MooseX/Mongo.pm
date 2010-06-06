use v5.10;
package MooseX::Mongo;
use MongoDB;
use MooseX::Singleton;
use MooseX::Mongo::Meta::Attribute::DoNotSerialize;

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
use Scalar::Util qw/refaddr reftype/;
use Carp;
use List::Util qw/first/;
#with Storage;
	
	has '_id' => ( is=>'rw', isa=>'MongoDB::OID', metaclass=>'DoNotSerialize' );
	#has '_last_state' => ( is=>'rw', isa=>'Str', default=>'', metaclass=>'DoNotSerialize' );

	sub _pk {}
	sub _method { 'damn' }
	sub save {
		my ($self, @from )=@_;
		my $coll = $self->collection;
		my $doc = $self->collapse( @from );
		return unless defined $doc;
		if( $self->_id  ) {
			#say $self->collection_name . ' - save from id';
			my $ret = $coll->update( { _id=>$self->_id }, $doc );
			return $ret;
		} else {
			if( $self->_pk ) {
				#say ref($doc) . ' - upsert from pk';
				my $pk = $self->primary_key_from_hash($doc);
				my $ret = $coll->update( $pk, $doc, { upsert=>1 } );
				my $_id = $coll->find_one( $pk, { _id=>1 } );
				$self->_id( $_id->{_id} );
				return $ret;
			} else {
				#say ref($doc) . ' - save without pk' . exists($doc->{_last_state} );
				my $id = $coll->save( $doc );
				$self->_id( $id );
				return $id; 
			}
		}
	}
	sub collapse {
		my ($self, @from )=@_;
		return $self
			if first { refaddr($self) == refaddr($_) } @from; #check for circularity
		my $packed = { %$self }; # cheesely clone the data 
		for my $key ( keys %$packed ) {
			my $obj = $packed->{$key};
			if( my $attrib = $self->meta->get_attribute($key) ) {
				delete $packed->{$key} , next
					if $attrib->does('MooseX::Mongo::Meta::Attribute::DoNotSerialize');
			}
			if( my $class =blessed $obj ) {
				#say "checking.... $class....";
				if( $class->can('meta') ) { # only mooses from here on 
					if( $class->does('EmbeddedDocument') ) {
						$packed->{$key} = $obj->collapse( @from, $self ) or next;
					}
					elsif( $class->does('Document') ) {
						$obj->save( @from, $self );
						my $id = $obj->_id;
						$packed->{$key} = { '$ref' => $class->collection_name, '$id'=>$id };
					} 
				} else {
					#use Data::Structure::Util 'get_blessed';
					#say "oo=" . join ',',map { ref } @{get_blessed($obj)};
					#say "oo=" . ref($obj);
					my $reftype = reftype($obj);
					if( $reftype eq 'ARRAY' ) {
						$packed->{$key} = [ @$obj ];
					} elsif( $reftype eq 'SCALAR' ) {
						$packed->{$key} = $$obj;
					} elsif( $reftype eq 'HASH' ) {
						$packed->{$key} = { %{$obj} };
					}
				}
			} elsif( ref $obj eq 'ARRAY' ) {
				my @docs;
				my $aryclass;
				for( @$obj ) {
					$aryclass ||= blessed( $_ );
					if( $aryclass && $aryclass->does('EmbeddedDocument') ) {
						push @docs, $_->collapse(@from, $self);
					} elsif( $aryclass && $aryclass->does('Document') ) {
						$_->save( @from, $self );
						my $id = $_->_id;
						push @docs, { '$ref' => $aryclass->collection_name, '$id'=>$id };
					} else {
						push @docs, $_;
					}
				}
				$packed->{$key} = \@docs;
			} 
		}
		return $packed;
	}
	sub collapse_raw {
		return shift;
	}
	sub collapse_pack {
		return shift->pack;
	}
	sub get_blessed_type {
		my ($self,$type) = @_;
		my $class = $type->name or return;
		my $parent = $type->parent;
		return $class if $parent eq 'Object';
		return $parent->name;
	}

	# shallow delete
	sub delete {
		my ($self, $args )=@_;
		return $self->collection->remove($args) if ref $args;
		my $id = $self->_id;
		return $self->collection->remove({ _id => $id }) if ref $id;
		my $pk = $self->primary_key_from_hash();
		return $self->collection->remove($pk) if ref $pk;
		return undef;
	}
	sub delete_cascade {
		my ($self, $args )=@_;
		#TODO delete related collections
	}
	sub expand {
		my ($self,$doc,@from)=@_;
		my @later;
		my $coll_name = $self->collection_name;
		my $class = ref $self || $self;
		for my $attr ( $class->meta->get_all_attributes ) {
			my $name = $attr->name;
			next unless exists $doc->{$name};
			my $type = $attr->type_constraint or next;
			my $class = $self->get_blessed_type( $type );
			$class or next;
			if( $type->is_a_type_of('ArrayRef') ) {
				my $array_class = $type->{type_parameter} . "";
				#say "ary class $array_class";
				my @objs;
				for my $item ( @{ $doc->{$name} || [] } ) {
					if( my $_id = delete $item->{'$id'} ) {
						if( my $circ_doc = first { $_->{_id} eq $_id } @from ) {
							push @objs, bless( $circ_doc , $array_class );
						} else {	
							my $ary_obj = $array_class->find_one({ _id=>$_id }, undef, @from, $doc );
							push @objs, $ary_obj if defined $ary_obj;
						}
					}
				}
				$doc->{$name} = \@objs;
				next;
			}
			#say "type=$type" . $type->is_a_type_of('ArrayRef');
			#say "type=$type, class=$class" . $type->{type_parameter};
			if( $class->can('meta') ) { # moose subobject
				if( $class->does('EmbeddedDocument') ) {
					$doc->{$name} = $class->new( $doc->{$name} ) ;
				} elsif( $class->does('Document') ) {
					if( my $_id = delete $doc->{$name}->{'$id'} ) {
						if( my $circ_doc = first { $_->{_id} eq $_id } @from ) {
							$doc->{$name} = bless( $circ_doc , $class );
						} else {	
							$doc->{$name} = $class->find_one({ _id=>$_id }, undef, @from, $doc );
						}
					}
				} 
			}
			else { #non-moose
				my $data = delete $doc->{$name};
				my $data_type =  ref $data;
				#say "ref=$data_type";
				if( !$data_type ) {
					#$doc->{$name} = bless \( $data ) => $class;
					#$doc->{$name} = $class->new( $data );
					push @later, { attrib=>$name, value=>$data };
				} else {
					$doc->{$name} = bless $data => $class;
				}
			}
		}
		#for my $key ( grep { ref($doc{$_}) eq 'ARRAY' } keys %$doc ) {
			#for my $item ( @{ $doc{$key} || [] } ) {
				#if( ref($item) eq 'HASH' && exists( $item->{'$id'} ) ) {
					#$doc{$key} = 
				#}
			#}
		#}
		#my $obj = $coll_name->new( $doc );
		return undef unless defined $doc;
		my $obj = bless $doc => $class;
		for( @later )  {
			my $meth = $_->{attrib};
			$obj->$meth($_->{value});
		}
		return $obj;
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
		my $coll = $db->get_collection( $coll_name );
	}
	sub primary_key_from_hash {
		my ($self,$hash)=@_;
		my @keys = $self->_pk;
		return { map { $_ => $self->{$_} } @keys };
	}
	sub find {
		my ($self,$query,$attrs) = @_;
		my $cursor = bless $self->collection->find($query,$attrs), 'MooseX::Mongo::Cursor';
		$cursor->_collection_name( $self->collection_name );
		$cursor->_class( ref $self || $self );
		return $cursor;
	}
	sub query {
		my ($self,$query,$attrs) = @_;
		my $cursor = bless $self->collection->query($query,$attrs), 'MooseX::Mongo::Cursor';
		$cursor->_collection_name( $self->collection_name );
		$cursor->_class( ref $self || $self );
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
		lc( ref $self || $self );
	}

package EmbeddedDocument;
use Moose::Role; 
with 'Document';

package Moose::Meta::Attribute::Custom::Trait::PrimaryKey;
use Moose::Role;

package DocumentID;
use Moose;
#use MooseX::Storage;
extends 'MongoDB::OID';
#with Storage;


package MooseX::Mongo::Cursor;
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

package MooseX::Mongo::Digest;
use Moose;
	sub modified {
		my ($self)=@_;
		my $ls = $self->_last_state;
		return 1 if !defined($ls) || $ls ne $self->_get_state;
	}
	sub _get_state {
		my ($self)=@_;
		use Digest::SHA qw(sha256_hex);
		my $ls = delete $self->{_last_state};
		my $s = do {
			local $Data::Dumper::Indent   = 0;
			local $Data::Dumper::Sortkeys = 1;
			local $Data::Dumper::Terse    = 1;
			local $Data::Dumper::Useqq    = 0;
			sha256_hex $self->dump;
		};
		#$self->_last_state( $ls ) if $ls;
		return $s;
	}
	sub _set_state {
		my ($self)=@_;
		#$self->_last_state( $self->_get_state );
	}

1;

=head1 SYNOPSIS

	package Person;
	with 'MooseX::Mongo::Document';
	has 'name' => ( is=>'rw', isa=>'Str' );

	package main;
	use MooseX::Mongo;

	my $person = Person->new( name=>'Jack' );
	$person->save;

	my $person = Person->find_one({ name=>'Jack' });

	my $cursor = Person->find({ name=>'Jack' });
	die "Not found" unless defined $cursor;
	while( my $person = $cursor->next ) {
		say "You're " . $person->name;	
	}


=head1 DESCRIPTION

This is a MongoDB-Moose object mapper. This module allows you to use the full
power of MongoDB with your Moose objects, without sacrificing MongoDB's
power, flexibility and speed.

It's loosely inspired by Ruby's MongoMapper,
which is in turn based on the ActiveRecord pattern. 

=head1 Why not use KiokuDB?

KiokuDB is an awesome distribution that maps objects to data
and caters to a wide variety of backends. Currently there's even a
MongoDB backend that may suit your needs. 

Why use this module instead?

* You want your objects to have their own collection. KiokuDB stores all objects in 
a single collection. MongoDB performs best the more collections you have.

* You want to be able to store relations as either embedded documents or
foreign documents. KiokuDB embeds everything. Here you get to choose.

* You want to abstract your data from your class representation. KiokuDB stores
an extra field called __CLASS__ that ties data to its representation. 
It's not a bad decision, it's just a design choice. 

* You feel adventurous. 

If you don't need any of this, grab KiokuDB. It's much more configurable,
stable and you get the option to switch backends in the future. 

=head1 REQUIREMENTS

Moose classes.
MongoDB installed.
MongoDB Perl driver.

=head1 FEATURES

Some of the features:

* It's fast. Not as fast as working with MongoDB documents directly though.
But it's way faster than any other ORM and relation-based mapping modules
out there. 

* It handles most object relationships, circular references included.

* No persistency. It doesn't manage states for your object. If you save
your object twice, it writes twice to the database. In most cases,
this is actually faster than trying to manage states. 

* Primary keys. This is quite a extraneuos concept for objects, and 
it's not mandatory. But it allows you to automatically control 
when new objects translate to new MongoDB documents, or just update
them. 

* Schema-less data. MongoDB does not hold a schema. You can create
new attributes for your object and delete old ones at your leasure.

* No data-object binding means that you may reuse collections,
and peruse inheritance to a great extent. 

=head1 CAVEATS

* This is very much *BETA* software. In fact it's almost alpha, except that the
API is so simple it will probably not change, so let's call it "beta". 

* This module intrusively imports singleton based methods into your class. It's 
the price to pay for a simpler user interface and less keystrokes. 

* Object expansion from the database is done using plain bless most of the time.
Which means your attribute triggers, etc. will not be fired during expansion.
There are exceptions to this rule though. 

* After saving or loading objects from the database, your object will have
an extra attribute, _id. This is a unique identifier. The _id value can be overwritten 
if you wish.

=head1 DESIGN

To make your Moose classes "Mongoable", all they need is to consume either
one of two roles: Document or EmbeddedDocument.

Then connect to the database. This is done globally for simplicity sake.

	use MooseX::Mongo;
	MooseX::Mongo->db('mydb'); # looks for a localhost connection

	# or, for more control:

	MooseX::Mongo->db(
		host=>'data.server',
		port=>4000,
		db=>'mydb');           

The difference between these roles lies in the way objects
will be later stored and loaded from the DB. 
Read the MongoDB docs if you don't understand the difference. 

Either one of these roles will import into your class the following methods:

=head3 save

Saves the current object to the database, inserting the document if needed.

	$person->save;

=head3 find

Wraps MongoDB's find method to return a cursor that expands data into objects.

=head3 query

	my $cursor = Person->query({ age => { '$lt' => 30 } });

=head3 find_one

=head3 collection

Returns the MongoDB::Collection object supporting this class. The collection
is designed 

=head2 Document

Akin to a row in the relational model. Relationships are stored using
MongoDB's foreign key system. 

=head2 EmbbededDocument

Tells MooseX::Mongo to store this as an embedded document, part of 
a parent document. 

=head1 TODO

* Allow query->fields to control which fields get expanded into the object. 


=cut
