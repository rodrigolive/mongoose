use Test::More;
use v5.10;
use YAML;
sub x::pp { say Dump( @_ ) }

{
	package Person;
	use Mongoose::Class;
	with 'Mongoose::Document';
	has_one 'name' => 'Str';
}
{
	package Thing;
	use Mongoose::Class;
	with 'Mongoose::Document' => {
		-pk => ['name'],
	};
	has_one 'name' => 'Str';
	has_one 'age' => 'Int';
	has_one 'alive' => 'Bool';
	has_one 'alive_more' => 'ArrayRef';
	has_one 'hh' => 'HashRef[ArrayRef]';
	has_one 'tt' => 'HashRef[Person]';
    has_one 'arr' => 'ArrayRef[Person]';
    has_one 'arr_int' => 'ArrayRef[Int]';
	has 'cc' => ( is=>'rw', isa=>'CodeRef', traits=>['DoNotSerialize'] );

	sub foo { print 'me' }

	around 'collapse' => sub {
		my ($orig, $self, @args ) = @_;
		my $ret = $orig->( $self, @args );
		#say 'checking....' . x::pp( $ret );
		#$ret->{alive_more} = [ '55' ];
		return $ret;
	};
}

{
	package main;
	use strict;
	use Benchmark;
	use Mongoose;
	Mongoose->db('test');
	Thing->collection->drop;
	my $na = "adf";
	my $t = Thing->new( alive_more=>[55], tt=>{ aa=>Person->new(name=>'Bobby') },
		hh=>{ aa=>[11,22,33] },
        arr => [ Person->new(name=>'Karen' ) ],
        arr_int => [ 10, 11, 23 ],
        name => 'Jack', age=>22, alive=>0, cc=>sub{ say $na } );

	#use B::Deparse;
    #    my $deparse = B::Deparse->new("-p", "-sC");
    #    my $body = $deparse->coderef2text( $t->cc );
	#	say $body;
        #my $cc = eval "sub $body"; # the inverse operation
		#$cc->();

	print $t->dump;
	$t->save;
	my $t2 = Thing->find_one;
	print $t2->dump;

    is ref($t2->tt), 'HASH', 'expanded hash 1';
    is ref($t2->tt->{aa}), 'Person', 'expanded hash key into class';
    is $t2->alive_more->[0], 55, 'basic arrayref resolved';
    is $t2->tt->{aa}->name, 'Bobby', 'doc $ref resolved';
    is $t2->arr->[0]->name, 'Karen', 'doc array $ref resolved';
    is $t2->arr_int->[0],  10, 'doc array $ref resolved';
    is ref($t2->hh), 'HASH', 'expanded hash 2';
    is ref($t2->hh->{aa}), 'ARRAY', 'expanded hash into array';
	#Benchmark::timethis( 20000, sub {
		#Thing->new( name => 'Jack'.$_ )->save;
	#});
	say "Ok";
	#Thing->find->each(sub{ say $_[0]->{name} } );
}

done_testing;
