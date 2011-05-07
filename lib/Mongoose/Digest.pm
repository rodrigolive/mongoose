package Mongoose::Digest;
use Any::Moose;
use Digest::SHA;

	sub _modified {
		my ($self)=@_;
		my $ls = $self->_last_state;
		return 1 if !defined($ls) || $ls ne $self->_get_state;
	}

	sub _get_state {
		my ($self)=@_;
		use Digest::SHA qw(sha256_hex);
		my $ls = delete $self->{_last_state};
		my $s = do {
			local $Data::Dumper::Indent   = 0;
			local $Data::Dumper::Sortkeys = 1;
			local $Data::Dumper::Terse    = 1;
			local $Data::Dumper::Useqq    = 0;
			sha256_hex $self->dump;
		};
		#$self->_last_state( $ls ) if $ls;
		return $s;
	}

	sub _set_state {
		my ($self)=@_;
		#$self->_last_state( $self->_get_state );
	}

=head1 NAME

Mongoose::Digest - deprecated persistance document state keeper

=head1 DESCRIPTION

An object persistence state keeper using a SHA 256 digest.

Not used for now, due to performance reasons. 

=cut 

1;
