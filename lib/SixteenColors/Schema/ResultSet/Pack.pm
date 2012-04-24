package SixteenColors::Schema::ResultSet::Pack;

use strict;
use warnings;

use SixteenColors::Archive;
use Image::TextMode::SAUCE;
use Try::Tiny;
use XML::Atom::SimpleFeed;
use Path::Class::File;

use parent 'DBIx::Class::ResultSet::Data::Pageset';

sub new_from_file {
    my ( $self, $file, $year, $c ) = @_;

    my $archive =  try {
        local $SIG{ __WARN__ } = sub { die shift };
        return SixteenColors::Archive->new( { filename => "$file" } );
    }
    catch {
        die $_;
    };

    my @manifest = $archive->files;
    my $schema = $self->result_source->schema;

    my $pack;
    my $pack_file = $c->path_to( 'root',
        $self->result_class->pack_file_location( $file, $year ) );

    try {
        $schema->txn_do( sub {
            $pack_file->dir->mkpath;
            File::Copy::copy( $file, "${pack_file}" ) unless -e "${pack_file}";

            $pack
                = $self->create( { file_path => "${pack_file}", year => $year } );
            my $dir = $pack->extract;

            my %seen_dirs;
            for my $f ( @manifest ) {
                my $name = $dir->exists( $f );
                
                unless( defined $name ) {
                    warn "File from pack not found: $f";
                    next;
                }

                next if -d $name;

                # handle directories
                my $parent = 0;
                if( $f =~ m{/} ) {
                    my @path = split( m{/}, $f );
                    pop @path; # ignore file portion
                    my $full_path = '';
                    my $last = 0;
                    for ( @path ) {
                        $full_path .= "/$_";
                        $full_path =~ s{^/}{};

                        unless( $seen_dirs{ $full_path } ) {
                            my $return = $pack->add_to_files( { file_path => $full_path, is_directory => 1, parent_id => $parent } );
                            $seen_dirs{ $full_path } = $return->id;
                            $parent = $return->id;
                        }

                        $parent = $seen_dirs{ $full_path };
                    }
                }

                # TODO: handle archives

                my $sauce = Image::TextMode::SAUCE->new;

                my $fh = $name->open( 'r' );
                $sauce->read( $fh );
                close( $fh );

                my $newfile = $pack->add_to_files( { file_path => $f, parent_id => $parent } );
                $newfile->add_sauce_from_sauce_object( $sauce );
                next unless $newfile->is_textmode;

                $newfile->fulltext(
                    Image::TextMode::Loader->load( "$name" )->as_ascii );
            }
        } );
    }
    catch {
        unlink $pack_file unless Path::Class::File->new( $file )->absolute eq $pack_file;
        die $_;
    };

    return $pack;
}

sub random {
    my $self = shift;
    $self->search( {}, { order_by => 'RANDOM()' } );
}

sub recent {
    my ( $self ) = @_;
    return $self->search( {}, { order_by => 'ctime DESC' } );
}

sub TO_JSON {
    my $self = shift;

    $self = $self->search( {}, {
        prefetch => {
            group_joins => 'art_group'
        }
    } );

    return [ map {
        {   name     => $_->canonical_name,
            filename => $_->filename,
            year     => $_->year,
            month    => $_->month,
            groups   => [
                map { { name => $_->name, shortname => $_->shortname } }
                map { $_->art_group }
                $_->group_joins
            ],
        }
    } $self->all ];
}

sub TO_FEED {
    my( $self, $c, $defaults ) = @_;

    $self = $self->search( {}, { order_by => 'ctime DESC' } );

    my %feed_info = %$defaults;
    $feed_info{ updated } = $self->first->ctime . 'Z';

    my $feed = XML::Atom::SimpleFeed->new( %feed_info );

    $self->reset;
    while( my $pack = $self->next ) {
        my $link = $c->uri_for( '/pack', $pack->canonical_name );
        $feed->add_entry(
            link  => $link,
            id    => $link,
            title => $pack->canonical_name,
            summary => $pack->description_as_html || undef,
        );
    }

    return $feed;
}

1;
