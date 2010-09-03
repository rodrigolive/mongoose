package Mongoose::Engine::Base;
BEGIN {
  $Mongoose::Engine::Base::VERSION = '0.03';
}
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
		my $attrib = $self->meta->get_attribute($key);

		# treat special cases based on Moose attribute defs or traits
		if( defined $attrib ) {
			delete $packed->{$key} , next
				if $attrib->does('Mongoose::Meta::Attribute::Trait::DoNotSerialize');

			next if $attrib->does('Mongoose::Meta::Attribute::Trait::Raw');

			if( my $type = $attrib->type_constraint ) {
				if( $type->is_a_type_of('FileHandle') ) {
					my $grid = $self->db->get_gridfs;	
					my $id = $grid->put( delete $packed->{$key} );
					$packed->{$key} = { '$ref'=>'FileHandle', '$id'=>$id };
				}
			}
		}

		my $obj = $packed->{$key};
		if( my $class = blessed $obj ) {
			#say "checking.... $class....";
			$packed->{$key} = $self->_unbless( $obj, $class, @scope );
		}
		elsif( ref $obj eq 'ARRAY' ) {
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
		elsif( ref $obj eq 'HASH' ) {
			my @docs;
			for my $key ( grep { blessed $obj->{$_} } keys %$obj ) {
				$obj->{$key} = $self->_unbless( $obj->{$key}, blessed($obj->{$key}), @scope );; 
			}
		}
	}
	return $packed;
}

sub _unbless {
	my ($self, $obj, $class, @scope ) = @_;
	my $ret = $obj;
			if( $class->can('meta') ) { # only mooses from here on 
				if( $class->does('Mongoose::EmbeddedDocument') ) {
					$ret = $obj->collapse( @scope, $self ) or next;
				}
				elsif( $class->does('Mongoose::Document') ) {
					$obj->save( @scope, $self );
					my $id = $obj->_id;
					$ret = { '$ref' => $class->meta->{mongoose_config}->{collection_name}, '$id'=>$id };
				} 
				elsif( $class->isa('Mongoose::Join') ) {
					$ret = [ $obj->_save( $self, @scope ) ];
				} 
			} else {
				# non-moose class
				my $reftype = reftype($obj);
				if( $reftype eq 'ARRAY' ) {
					$ret = [ @$obj ];
				} elsif( $reftype eq 'SCALAR' ) {
					$ret = $$obj;
				} elsif( $reftype eq 'HASH' ) {
					$ret = { %{$obj} };
				}
			}
	return $ret;
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
        my $type = $attr->type_constraint or next;
		my $class = $self->_get_blessed_type( $type );
		$class or next;

		if( defined $attr && $attr->does('Mongoose::Meta::Attribute::Trait::Raw') ) {
			next;
		}
		elsif( $type->is_a_type_of('HashRef') ) {
			if(  defined $type->{type_parameter} ) {
				my $hash_class = $type->{type_parameter} . "";
				my @objs;
				for my $item ( values %{ $doc->{$name} || {} } ) {
					if( my $_id = delete $item->{'$id'} ) {
						if( my $circ_doc = $scope->{ $_id } ) {
							push @objs, bless( $circ_doc , $hash_class );
						} else {	
							push @$scope, $doc; 
							my $hash_obj = $hash_class->find_one({ _id=>$_id }, undef, $scope );
							push @objs, $hash_obj if defined $hash_obj;
						}
					}
				}

			} else {
				# nothing to do on HASH
				next;
			}
		}
		elsif( $type->is_a_type_of('FileHandle') ) {
			my $file = $self->db->get_gridfs->find_one({ _id=>$doc->{$name}->{'$id'} });
			delete $doc->{$name}, next unless defined $file;
			$doc->{$name} = bless $file, 'Mongoose::File';
			next;
		}
		elsif( $type->is_a_type_of('ArrayRef') ) {
			if(  defined $type->{type_parameter} ) {
				# ArrayRef[ parameter ]
				my $array_class = $type->{type_parameter} . "";
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
			} else {
				# old plain ArrayRef
				next;
			}
		}
		if( $class->can('meta') ) { # moose subobject

			if( $class->does('Mongoose::EmbeddedDocument') ) {
				$doc->{$name} = bless $doc->{$name}, $class;
			}
			elsif( $class->does('Mongoose::Document') ) {
				if( my $_id = delete $doc->{$name}->{'$id'} ) {
					if( my $circ_doc = $scope->{"$_id"} ) {
						$doc->{$name} = bless( $circ_doc , $class );
						$scope->{ "$circ_doc->{_id}" } = $doc->{$name}; 
					} else {	
						$scope->{ "$doc->{_id}" } = $doc;
						$doc->{$name} = $class->find_one({ _id=>$_id }, undef, $scope );
					}
				}
			}
			elsif( $class->isa('Mongoose::Join') ) {
				my $ref_arr = delete( $doc->{$name} );
				my $ref_class = $type->type_parameter->class ;
                if( $class eq 'Mongoose::Join::Relational' ){
                    $doc->{$name} = $class_main->meta->get_attribute($name)->default->($doc);

                }else{
                    $doc->{$name} = bless {
                                           class=>$class_main, field=>$name, parent=>$doc->{_id}, with_class=>$ref_class,
                                           children=>$ref_arr, buffer=>{}
                                          } => $class;
                }
			}
		}
		else { #non-moose
			my $data = delete $doc->{$name};
			my $data_type =  ref $data;

			if( !$data_type ) {
				push @later, { attrib=>$name, value=>$data };
			} else {
				$doc->{$name} = bless $data => $class;
			}
		}
	}

	return undef unless defined $doc;
	my $obj = bless $doc => $class_main;
	for( @later )  {
		my $meth = $_->{attrib};
		$obj->$meth($_->{value});
	}
	return $obj;
}

sub _joint_fields {
	my $self = shift;
	return map { $_->name }
		grep { 
			$_->type_constraint->isa('Mongoose::Join')
		}
		$self->meta->get_all_attributes ;
}

sub fix_integrity {
	my ($self, @fields ) = @_;
	my $id = $self->_id;
	@fields = $self->_joint_fields
		unless scalar @fields;
	for my $field ( @fields ) {
		my @children = $self->$field->_children_refs;
		$self->collection->update( { _id=>$id }, { '$set'=>{ $field=>\@children } } );
	}
}

sub _unbless_full {
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

sub _collection_name {
	my $self = shift;
	return $self->meta->{mongoose_config}->{collection_name} ;
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

=head1 VERSION

version 0.03

=head1 DESCRIPTION

The Mongoose standard engine. Does all the dirty work. Very monolithic. 
Replace it with your engine if you want. 

=head1 METHODS

=head2 find_one

Just like L<MongoDB::Collection/find_one>, but blesses the hash document
into your class package.

=head2 find

Just like L<MongoDB::Collection/find>, but returns
a L<Mongoose::Cursor> of documents blessed into
your package.

=head2 query

Just like L<MongoDB::Collection/query>, but returns
a L<Mongoose::Cursor> of documents blessed into
your package.

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

=head2 fix_integrity

Checks all L<Mongoose::Join> fields for invalid references to 
foreign object ids.  

=cut 

1;

