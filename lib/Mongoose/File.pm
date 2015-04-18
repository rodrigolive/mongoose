package Mongoose::File;

use Moose;

extends 'MongoDB::GridFS::File';

sub delete {
    my $self = shift;
    my $id = $self->info->{ _id };
    return $self->_grid->delete( $id ); 
}

*drop = \&delete;

=head1 NAME

Mongoose::File - wrapper for MongoDB::GridFS::File

=head1 DESCRIPTION

This module is automatically used when your class
has C<FileHandle> type attributes.

It extends L<MongoDB::GridFS::File> and adds a
few convenience methods to it. 

=head1 METHODS

=head2 delete

Deletes the GridFS file entry.

=head2 drop

Same as delete

=cut

1;
