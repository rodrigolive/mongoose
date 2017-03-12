package Mongoose::File;

use Moose;

has file_id => ( is => 'ro', isa => 'MongoDB::OID', required => 1 );
has bucket  => ( is => 'ro', isa => 'MongoDB::GridFSBucket', required => 1 );

has stream_download =>
    is      => 'ro',
    isa     => 'MongoDB::GridFSBucket::DownloadStream',
    lazy    => 1,
    default => sub { $_[0]->bucket->open_download_stream($_[0]->file_id) },
    handles => [qw/ fh readline read eof fileno getc /];

sub slurp { local $/; shift->readline; }

sub delete {
    my $self = shift;
    $self->bucket->delete($self->file_id);
    $self->file_id;
}

*drop = \&delete;

=head1 NAME

Mongoose::File - container for MongoDB::GridFSBucket files

=head1 DESCRIPTION

This module is automatically used when your class
has C<FileHandle> type attributes.

It wraps L<MongoDB::GridFSBucket::DownloadStream> and adds a
few convenience methods to it.

=head1 METHODS

=head2 delete

Deletes the GridFS file entry.

=head2 drop

Same as delete

=cut

=head2 slurp

Retrieve the full content of the file at once.

=cut

__PACKAGE__->meta->make_immutable();
