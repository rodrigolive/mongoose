#!/usr/bin/perl
use strict;

{   package Explorer;

    use HTTP::Server::Simple::CGI;
    use Moose;
    use Switch;
    use File::Spec::Functions qw(rel2abs);
    use File::Basename;
    use Slurp;
    use JSON::DWIW;
    use Scalar::Util qw(blessed);

    extends qw/HTTP::Server::Simple::CGI/;

    sub handle_request {
        my $self = shift;
        my $cgi  = shift;
        my $path = $cgi->path_info();
        my $response = {};
        switch($path){
            case qr/^\/(index\.html)*$/i          { $self->static( $cgi, '/index.html') }
            case qr/^\/static\//i                 { $self->static( $cgi, $path =~ m{^\/static\/(.*)}ig ) }
            case qr/^\/eval\//i                   { $self->eval( $cgi ) }
            case qr/^\/eval_query\//i             { $self->eval_query( $cgi ) }
            else                                  { $self->not_found( $cgi ) }
        }
    }

    sub eval{
        my ( $self, $cgi ) = @_;
        use lib '/home/arthur/dev/svn/libs/';
        use DB;
        print "HTTP/1.0 200 OK\r\n";
        print $cgi->header('application/json');
        my $value;
        eval 'my $db = db();my $eval_code = sub{' . $cgi->param('code') . '}; $value = $eval_code->();';
        print $@ if $@;
        print JSON::DWIW->to_json($value);
    }

    sub eval_query{
        my ( $self, $cgi ) = @_;
        use lib '/home/arthur/dev/svn/libs/';
        use DB;
        print "HTTP/1.0 200 OK\r\n";
        print $cgi->header('application/json');
        my $value;
        eval 'my $db = db();my $eval_code = sub{my $a = ' . $cgi->param('code') . '; return $a}; $value = $eval_code->();';
        if( $@ ){
            print JSON::DWIW->to_json({type => 'error', error => [ split( /at \(eval/, $@ ) ]->[0] });
        }else{
            use Data::Dumper;
            my $data = { type => 'unknown', raw_data => Data::Dumper->Dump([$value]), count => 0 };
            if( my $class = blessed $value ){
                if( $class eq 'DateTime' ){
                    $data->{type} = 'datetime';
                    $data->{date} = $value->ymd('-') . ' ' . $value->hms(':');
                }
                if( $class eq 'MongoDB::OID' ){
                    $data->{type} = 'id';
                    $data->{id} = $value->value;
                }
                if( $class eq 'Mongoose::Join::Relational' ){
                    $data->{type} = 'join';
                    $data->{class} = $value->with_class;
                    $data->{count} = $value->count;
                    $data->{documents} = $self->expand($cgi, $value->resultset) if $cgi->param('expand');
                }
                if( $class eq 'Mongoose::Resultset' ){
                    $data->{type} = 'resultset';
                    $data->{class} = $value->_class;
                    $data->{count} = $value->count;
                    $data->{documents} = $self->expand($cgi, $value) if $cgi->param('expand');
                }
                if( $class eq 'Mongoose::Cursor' ){
                    $data->{type} = 'cursor';
                    $data->{class} = $value->_class;
                    $data->{count} = $value->count;
                }
                if( $class->can('meta') && $class->does('Mongoose::Document') ){
                    $data->{type} = 'document';
                    $data->{class} = $class;
                    $data->{documents} = $self->expand($cgi, $value->resultset->search({'_id' => $value->_id})->limit(1)) if $cgi->param('expand');
                }
            }else{

            }
            print JSON::DWIW->to_json($data);
        }
    }

    sub expand{
        my ( $self, $cgi, $resultset ) = @_;
        unless( $resultset->{_attributes}->{skip} ){ $resultset = $resultset->skip( int($cgi->param('skip') )); }
        unless( $resultset->{_attributes}->{limit} ){ $resultset = $resultset->limit( int($cgi->param('limit')) ); }
        my $data = { list => [map { $self->collapse($_) } $resultset->all] , attributes => [map { {name => $_->name, constraint => $_->type_constraint->name } } $resultset->_class->new->meta->get_all_attributes] };
        return $data;
    }

    sub collapse{
        my ( $self, $document ) = @_;
        my $returner = $document->collapse;
        $returner->{_id} = $document->_id;
        my $date = DateTime->from_epoch(epoch => $document->_id->get_time);
        $returner->{_id_date} = $date->ymd('-') . ' ' . $date->hms(':');
        for my $attribute ( $document->meta->get_all_attributes ){
            if( $attribute->type_constraint->name =~ m{Mongoose::Join} ){
                $returner->{$attribute->name} = { count => $document->{$attribute->name}->count };
            }
        }
        return $returner;
    }

    sub static{
        my ( $self, $cgi, $path ) = @_;
        my $base = dirname(rel2abs($0)) . '/static/';
        if( -e $base . $path ){
            print "HTTP/1.0 200 OK\r\n";
            print $cgi->header($self->header($path)), slurp($base . $path);
        }else{
            $self->not_found;
        }
    }

    sub header{
        my ( $self, $path ) = @_;
        switch( $path ){
            case /\.css$/  { return 'text/css'}
            case /\.html$/ { return 'text/html'}
            case /\.jpg$/  { return 'image/jpg'}
            case /\.js$/   { return 'text/javascript'}
            else           { return 'text/html'}
        }
    }

    sub not_found{
        my ( $self, $cgi ) = @_;
        print "HTTP/1.0 404 Not found\r\n";
        print $cgi->header, "not found";        
    }

    


}

# start the server on port 8080
my $pid = Explorer->new(8080)->run();#->background();
print "Use 'kill $pid' to stop server.\n";
