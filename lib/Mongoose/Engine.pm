package Mongoose::Engine;
use Moose::Role;

with ( Mongoose->_mongodb_v1 ? 'Mongoose::Engine::V1' : 'Mongoose::Engine::V0' );

1;
