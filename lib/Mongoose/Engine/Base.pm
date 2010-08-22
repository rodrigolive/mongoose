package Mongoose::Engine::Base;
use Moose::Role;
use Params::Coerce;
use Scalar::Util qw/refaddr reftype/;
use Carp;
use List::Util qw/first/;
use Mongoose::Cursor; #initializes moose

with 'Mongoose::Role::Collapser';
with 'Mongoose::Role::Expander';
with 'Mongoose::Role::Engine';
	
sub collapse {
	my ($self, @scope )=@_;
	return $self
		if first { refaddr($self) == refaddr($_) } @scope; #check for circularity
	my $packed = { %$self }; # cheesely clone the data 
	for my $key ( keys %$packed ) {
		my $obj = $packed->{$key};
		if( my $attrib = $self->meta->get_attribute($key) ) {
			delete $packed->{$key} , next
				if $attrib->does('Mongoose::Meta::Attribute::Trait::DoNotSerialize');
		}
		if( my $class =blessed $obj ) {
			#say "checking.... $class....";
			if( $class->can('meta') ) { # only mooses from here on 
				if( $class->does('Mongoose::EmbeddedDocument') ) {
					$packed->{$key} = $obj->collapse( @scope, $self ) or next;
				}
				elsif( $class->does('Mongoose::Document') ) {
					$obj->save( @scope, $self );
					my $id = $obj->_id;
					$packed->{$key} = { '$ref' => $class->meta->{mongoose_config}->{collection_name}, '$id'=>$id };
				} 
				elsif( $class->isa('Mongoose::Join') ) {
					my @objs = $obj->_save( $self, @scope );
					$packed->{$key} = \@objs;
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
				if( $aryclass && $aryclass->does('Mongoose::EmbeddedDocument') ) {
					push @docs, $_->collapse(@scope, $self);
				} elsif( $aryclass && $aryclass->does('Mongoose::Document') ) {
					$_->save( @scope, $self );
					my $id = $_->_id;
					push @docs, { '$ref' => $aryclass->meta->{mongoose_config}->{collection_name}, '$id'=>$id };
				} else {
					push @docs, $_;
				}
			}
			$packed->{$key} = \@docs;
		} 
	}
	return $packed;
}

sub expand {
	my ($self,$doc,$fields,$scope)=@_;
	my @later;
	my $config = $self->meta->{mongoose_config};
	my $coll_name = $config->{collection_name};
	my $class_main = ref $self || $self;
	$scope = {} unless ref $scope eq 'HASH';
	for my $attr ( $class_main->meta->get_all_attributes ) {
		my $name = $attr->name;
		next unless exists $doc->{$name};
		my $type = $attr->type_constraint or next;
		my $class = $self->_get_blessed_type( $type );
		$class or next;

		if( $type->is_a_type_of('ArrayRef') ) {
			my $array_class = $type->{type_parameter} . "";
			#say "ary class $array_class";
			my @objs;
			for my $item ( @{ $doc->{$name} || [] } ) {
				if( my $_id = delete $item->{'$id'} ) {
					if( my $circ_doc = $scope->{ $_id } ) {
						push @objs, bless( $circ_doc , $array_class );
					} else {	
						push @$scope, $doc; 
						my $ary_obj = $array_class->find_one({ _id=>$_id }, undef, $scope );
						push @objs, $ary_obj if defined $ary_obj;
					}
				}
			}
			$doc->{$name} = \@objs;
			next;
		}
		elsif( $type->is_a_type_of('HashRef') ) {
			# nothing to do on HASH
			next;
		}
		#say "type=$type" . $type->is_a_type_of('ArrayRef');
		#say "type=$type, class=$class" . $type->{type_parameter};
		if( $class->can('meta') ) { # moose subobject
			if( $class->does('Mongoose::EmbeddedDocument') ) {
				$doc->{$name} = $class->new( $doc->{$name} ) ;
			} elsif( $class->does('Mongoose::Document') ) {
				if( my $_id = delete $doc->{$name}->{'$id'} ) {
					if( my $circ_doc = $scope->{"$_id"} ) {
						$doc->{$name} = bless( $circ_doc , $class );
						$scope->{ "$circ_doc->{_id}" } = $doc->{$name}; 
					} else {	
						$scope->{ "$doc->{_id}" } = $doc;
						$doc->{$name} = $class->find_one({ _id=>$_id }, undef, $scope );
					}
				}
			} elsif( $class->isa('Mongoose::Join') ) {
				my $ref_arr = delete( $doc->{$name} );
				#print "class=$class\n";
				#$doc->{$name} = bless { parent=>$doc->{'_id'} } => $class;
				#print "DOC=$doc,  name=$name, docname=" . $doc->{$name};
				my $ref_class = $type->type_parameter->class ;
				#$doc->{$name} = bless { parent=>$doc->{'_id'} } => $class;
				$doc->{$name} = bless { with_class=>$ref_class, children=>$ref_arr } => $class;
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
	my $obj = bless $doc => $class_main;
	for( @later )  {
		my $meth = $_->{attrib};
		$obj->$meth($_->{value});
	}
	return $obj;
}

sub _unbless {
	require Data::Structure::Util;
	Data::Structure::Util::unbless( shift );
}

sub save {
	my ($self, @scope )=@_;
	my $coll = $self->collection;
	my $doc = $self->collapse( @scope );
	return unless defined $doc;

	if( $self->_id  ) {
		## update on my id
		my $id = $self->_id;
		my $ret = $coll->update( { _id=>$id }, $doc, { upsert=>1 } );
		return $id;
	} else {
		if( ref $self->meta->{mongoose_config}->{pk} ) {
			## upsert using a primary key
			my $pk = $self->_primary_key_from_hash($doc);
			my $ret = $coll->update( $pk, $doc, { upsert=>1 } );
			my $id = $coll->find_one( $pk, { _id=>1 } );
			$self->_id( $id->{_id} );
			return $id->{_id};
		} else {
			# save without pk
			my $id = $coll->save( $doc );
			$self->_id( $id );
			return $id; 
		}
	}
}

sub _get_blessed_type {
	my ($self,$type) = @_;
	my $class = $type->name or return;
	my $parent = $type->parent;
	return $class unless defined $parent;
	return $class if $parent eq 'Object';
	return $parent->name;
}

# shallow delete
sub delete {
	my ($self, $args )=@_;
	return $self->collection->remove($args) if ref $args;
	my $id = $self->_id;
	return $self->collection->remove({ _id => $id }) if ref $id;
	my $pk = $self->_primary_key_from_hash();
	return $self->collection->remove($pk) if ref $pk;
	return undef;
}

#sub delete_cascade {
#	my ($self, $args )=@_;
#	#TODO delete related collections
#}

sub db {
	my $self=shift;
	return Mongoose->_db_for_class( ref $self || $self )
		or croak 'MongoDB not set. Set Mongoose->db("name") first';
}

sub collection {
	my ($self, $new_collection) = @_;
	my $db = $self->db;

	# getter
	my $config = $self->meta->{mongoose_config};
	$new_collection or return $config->{collection}
		|| ( $config->{collection} = $db->get_collection( $config->{collection_name} ) );

	# setter
	my $is_singleton = ! ref $self;
	if( ref($new_collection) eq 'MongoDB::Collection' ) {
		# changing collection objects directly
		if( $is_singleton ) {
			$config->{collection_name} = $new_collection->name;
			return $config->{collection} = $new_collection;
		} else {
			my $class = ref $self;
			Carp::confess "Changing the object collection is not currently supported. Use $class->collection() instead";
		}
	}
	elsif( $new_collection ) {
		# setup a new collection by name
		if( $is_singleton ) {
			$config->{collection_name} = $new_collection;
			return $config->{collection} = $db->get_collection( $new_collection );
		} else {
			my $class = ref $self;
			Carp::confess "Changing the object collection is not currently supported. Use $class->collection() instead";
		}
	}
}

sub _primary_key_from_hash {
	my ($self,$hash)=@_;
	my @keys = @{ $self->meta->{mongoose_config}->{pk} || [] };
	return { map { $_ => $self->{$_} } @keys };
}

sub find {
	my ($self,$query,$attrs) = @_;
	my $cursor = bless $self->collection->find($query,$attrs), 'Mongoose::Cursor';
	$cursor->_collection_name( $self->meta->{mongoose_config}->{collection_name} );
	$cursor->_class( ref $self || $self );
	return $cursor;
}

sub query {
	my ($self,$query,$attrs) = @_;
	my $cursor = bless $self->collection->query($query,$attrs), 'Mongoose::Cursor';
	$cursor->_collection_name( $self->meta->{mongoose_config}->{collection_name} );
	$cursor->_class( ref $self || $self );
	return $cursor;
}

sub find_one {
	my ($self,$query,$fields, $from) = @_;
	my $doc = $self->collection->find_one( $query, $fields );
	return undef unless defined $doc;
	return $self->expand( $doc, $fields, $from );
}

=head1 NAME

Mongoose::Engine::Base - heavy lifting done here

=head1 DESCRIPTION

The Mongoose standard engine. Does all the dirty work. Very monolithic. 
Replace it with your engine if you want. 

=head1 METHODS

=head2 find_one

Just like L<MongoDB::Collection/find_one>, but blesses the hash document
into your class package.

=head2 find

Just like L<MongoDB::Collection/find>, but returns
a L<Mongoose::Cursor> of blessed documents.

=head2 query

Just like L<MongoDB::Collection/find>, but returns
a L<Mongoose::Cursor> of blessed documents.

=head2 delete 

Deletes the document in the database.

=head2 collapse

Turns an object into a hash document. 

=head2 expand

Turns a hash document back into an object.

=head2 collection

Returns the L<MongoDB::Collection> object for this class or object.

=head2 save

Commits the object to the database.

=head2 db

Returns the object's corresponding L<MongoDB::Database> instance.

=cut 

1;
