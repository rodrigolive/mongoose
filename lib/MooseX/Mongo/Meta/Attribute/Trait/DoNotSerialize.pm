package MooseX::Mongo::Meta::Attribute::Trait::DoNotSerialize;
use Moose::Role;

# register this alias ...
package Moose::Meta::Attribute::Custom::Trait::DoNotSerialize;

sub register_implementation { 'MooseX::Mongo::Meta::Attribute::Trait::DoNotSerialize' }

1;

