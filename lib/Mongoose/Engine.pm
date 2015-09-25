package Mongoose::Engine;
use Moose::Role;

with ( Mongoose->_mongodb_v1 ? 'Mongoose::Engine::V1' : 'Mongoose::Engine::V0' );

=head1 NAME

Mongoose::Engine - Mongoose Engine loader

=head1 DESCRIPTION

This is just a loader for the real engine L<Mongoose::Engine::V1> for the new MongoDB driver v1.x.x
or L<Mongoose::Engine::V0> if you still use an old version of the driver.

=cut
1;
