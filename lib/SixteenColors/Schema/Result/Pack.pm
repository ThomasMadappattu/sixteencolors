package SixteenColors::Schema::Result::Pack;

use strict;
use warnings;

use parent 'DBIx::Class';

use File::Basename ();
use SixteenColors::Archive;
use GD ();
use Text::Markdown ();

__PACKAGE__->load_components( qw( TimeStamp Core ) );
__PACKAGE__->table( 'pack' );
__PACKAGE__->add_columns(
    id => {
        data_type         => 'bigint',
        is_auto_increment => 1,
        is_nullable       => 0,
    },
    filename => {
        data_type   => 'varchar',
        size        => 128,
        is_nullable => 0,
    },
    file_path => {
        data_type   => 'varchar',
        size        => 512,
        is_nullable => 0,
    },
    approved => {
        data_type     => 'boolean',
        default_value => 0,
        is_nullable   => 0,
    },
    annotation => {
        data_type   => 'text',
        is_nullable => 1,
    },
    year => {
        data_type   => 'integer',
        is_nullable => 0,
    },
    month => {
        data_type   => 'integer',
        is_nullable => 1,
    },
    thumbnail_id => {
        data_type      => 'bigint',
        is_foreign_key => 1,
        is_nullable    => 1,
    },
    ctime => {
        data_type     => 'timestamp',
        default_value => \'CURRENT_TIMESTAMP',
        set_on_create => 1,
    },
    mtime => {
        data_type     => 'timestamp',
        is_nullable   => 1,
        set_on_create => 1,
        set_on_update => 1,
    },
);
__PACKAGE__->set_primary_key( qw( id ) );
__PACKAGE__->add_unique_constraint( [ 'filename' ] );
__PACKAGE__->resultset_attributes( {
    order_by => [ 'year, month, filename' ],
    where    => { approved => 1 },
} );

__PACKAGE__->has_many(
    group_joins => 'SixteenColors::Schema::Result::PackGroupJoin' =>
        'pack_id' );
__PACKAGE__->many_to_many(
    groups => 'group_joins' => 'art_group',
    { order_by => 'name' }
);

__PACKAGE__->has_many(
    files => 'SixteenColors::Schema::Result::File',
    'pack_id'
);

__PACKAGE__->belongs_to(
    thumbnail => 'SixteenColors::Schema::Result::File',
    'thumbnail_id'
);

sub store_column {
    my ( $self, $name, $value ) = @_;

    if ( $name eq 'file_path' ) {
        $self->filename( lc File::Basename::basename( $value ) );
    }

    $self->next::method( $name, $value );
}

sub pack_file_location {
    my ( $self, $file, $year ) = @_;
    $file ||= $self->filename;
    $year ||= $self->year;

    my $basename = File::Basename::basename( $file );

    my $path = "/static/packs/${year}/${basename}";

    return $path;
}

sub pack_folder_location {
    my ( $self ) = shift;

    my $path = $self->pack_file_location( @_ );
    $path =~ s{\.[^.]+$}{};

    return $path;
}

sub extract {
    my $self = shift;
    return SixteenColors::Archive->new( { filename => $self->file_path } )->extract( @_ );
}

my @months
    = qw( January February March April May June July August September October November December );

sub formatted_date {
    my $self = shift;

    my $month = $self->month;
    my $year  = $self->year;

    return 'Date Unknown' unless $year;
    return $year unless $month;
    return join( ' ', $months[ $month - 1 ], $year );
}

sub group_name {
    my( $self, $c ) = @_;
    my @g = $self->groups;

    if( $c ) {
        @g = map { sprintf '<a href="%s">%s</a>', $c->uri_for( '/group', $_->shortname ), $_->name } @g;
    }
    else {
        @g = map { $_->name } @g;
    }

    push @g, 'Group Unknown' unless @g;
    return join ', ', @g;
}

sub annotation_as_html {
    return Text::Markdown::markdown( shift->annotation || '' );
}

sub generate_preview {
    my ( $self, $path ) = @_;

    my $pic
        = $self->files(
        \[ 'lower(filename) = ?', [ plain_value => 'file_id.diz' ] ],
        { rows => 1 } )->first;

    # Random pic if not DIZ exists
    if ( !$pic ) {
        my $files = $self->files( {}, { order_by => 'RANDOM()' } );
        $pic = $files->next until $pic && $pic->is_artwork;
    }

    my $SIZE   = 296;
    my $SIZE_S = 232;

    my $dir  = $self->extract;
    my $name = $dir->exists( $pic->file_path );

    $path = $path->dir unless $path->is_dir;
    $path->mkpath;

    my $source;

    if ( $pic->is_bitmap ) {
        $source = GD::Image->new( "$name" );
    }
    else {
        my $textmode = Image::TextMode::Loader->load( "$name" );
        my $renderer = Image::TextMode::Renderer::GD->new;
        $source = $renderer->fullscale( $textmode,
            { %{ $pic->render_options }, format => 'object' } );
    }

    my ( $w, $h ) = $source->getBounds;
    if ( $w > $h ) {
        $h = $source->height * $SIZE / $source->width;
        $w = $SIZE;
    }
    else {
        $w = $source->width * $SIZE / $source->height;
        $h = $SIZE;
    }

    my $resized = GD::Image->new( $SIZE, $SIZE, 1 );
    $resized->copyResampled(
        $source,
        int( ( $SIZE - $w ) / 2 ),
        int( ( $SIZE - $h ) / 2 ),
        0, 0, $w, $h, $source->getBounds
    );

    {
        my $fh = $path->file( $self->canonical_name . '.png' )->open( 'w' )
            or die "cannot write file ($path): $!";
        binmode( $fh );
        print $fh $resized->png;
        close( $fh );
    }

    my $small = GD::Image->new( $SIZE_S, $SIZE_S, 1 );
    $small->copyResampled( $resized, 0, 0, 0, 0, $small->getBounds,
        $resized->getBounds );

    {
        my $fh = $path->file( $self->canonical_name . '-s.png' )->open( 'w' )
            or die "cannot write file ($path): $!";
        binmode( $fh );
        print $fh $small->png;
        close( $fh );
    }

    $dir->cleanup;
}

sub TO_JSON {
    my $self = shift;
    return {
        name               => $self->canonical_name,
        filename           => $self->filename,
        year               => $self->year,
        month              => $self->month,
        pack_file_location => $self->pack_file_location,
        files              => $self->files_rs,
        uri                => join( '/', '/pack', $self->canonical_name ),
        groups             => [ map { { name => $_->name, shortname => $_->shortname } } $self->groups ],
    };
}

1;
