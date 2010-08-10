package Mongoose::Role::Engine;
use Moose::Role;

requires 'save';
requires 'delete';
requires 'find';
requires 'find_one';
requires 'query';
requires 'collection';

1;

