package SixteenColors::Schema::Result::Group;

use strict;
use warnings;

use parent qw( DBIx::Class );

use Text::Markdown ();

__PACKAGE__->load_components( qw( TimeStamp Core ) );
__PACKAGE__->table( 'group' );
__PACKAGE__->add_columns(
    id => {
        data_type         => 'bigint',
        is_auto_increment => 1,
        is_nullable       => 0,
    },
    name => {
        data_type   => 'varchar',
        size        => 512,
        is_nullable => 0,
    },
    shortname => {
        data_type   => 'varchar',
        size        => 64,
        is_nullable => 0,
    },
    thumbnail_id => {
        data_type      => 'bigint',
        is_foreign_key => 1,
        is_nullable    => 1,
    },
    history => {
        data_type   => 'text',
        is_nullable => 1,
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
__PACKAGE__->add_unique_constraint( [ 'shortname' ] );

__PACKAGE__->has_many(
    pack_joins => 'SixteenColors::Schema::Result::PackGroupJoin' =>
        'group_id' );
__PACKAGE__->many_to_many( packs => 'pack_joins' => 'pack' );

__PACKAGE__->has_many(
    artist_joins => 'SixteenColors::Schema::Result::ArtistGroupJoin' =>
        'group_id' );
__PACKAGE__->many_to_many( artists => 'artist_joins' => 'artist' );

__PACKAGE__->belongs_to(
    thumbnail => 'SixteenColors::Schema::Result::File',
    'thumbnail_id'
);

sub store_column {
    my ( $self, $name, $value ) = @_;

    if ( $name eq 'name' ) {
        my $short = lc $value;
        $short =~ s{[^a-z0-9]+}{_}g;
        $short =~ s{^_}{};
        $short =~ s{_$}{};
        $self->shortname( $short );
    }

    $self->next::method( $name, $value );
}

sub history_as_html {
    return Text::Markdown::markdown( shift->history || '' );
}

sub TO_JSON {
    my $self = shift;
    return { $self->get_columns };
}

1;
