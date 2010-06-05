package MooseX::Mongo::Meta::Attribute::DoNotSerialize;
use Moose;

extends 'Moose::Meta::Attribute';
   with 'MooseX::Mongo::Meta::Attribute::Trait::DoNotSerialize';

# register this alias ...
package Moose::Meta::Attribute::Custom::DoNotSerialize;

sub register_implementation { 'MooseX::Mongo::Meta::Attribute::DoNotSerialize' }

1;



