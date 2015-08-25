package Mongoose::Role::Engine;

use Moose::Role;

requires 'save';
requires 'delete';
requires 'find';
requires 'find_one';
requires 'query';
requires 'collection';

=head1 NAME

Mongoose::Role::Engine

=head1 DESCRIPTION

The engine role. No moving parts. Required by any engine wannabees.

=cut

1;

