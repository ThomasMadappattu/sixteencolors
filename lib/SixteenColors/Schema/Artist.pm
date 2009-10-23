package SixteenColors::Schema::Artist;

use strict;
use warnings;

use base qw( DBIx::Class );

__PACKAGE__->load_components( qw( TimeStamp Core ) );
__PACKAGE__->table( 'artist' );
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
        size        => 25,
        is_nullable => 0,
    },
    formerly_id => {
        data_type      => 'bigint',
        is_foreign_key => 1,
        is_nullable    => 1,
    },
    ctime => {
        data_type     => 'datetime',
        default_value => \'CURRENT_TIMESTAMP',
        set_on_create => 1,
    },
    mtime => {
        data_type     => 'datetime',
        default_value => \'CURRENT_TIMESTAMP',
        set_on_create => 1,
        set_on_update => 1,
    },
);
__PACKAGE__->set_primary_key( qw( id ) );
__PACKAGE__->add_unique_constraint( [ 'shortname' ] );

__PACKAGE__->has_many( files => 'SixteenColors::Schema::File', 'artist_id' );
__PACKAGE__->belongs_to(
    formerly => 'SixteenColors::Schema::Artist',
    'formerly_id'
);

sub insert {
    my $self = shift;

    if ( !$self->shortname ) {
        my $short = lc $self->name;
        $short =~ s{[^a-z0-9]+}{_}g;
        $short =~ s{^_}{};
        $short =~ s{_$}{};
        $self->shortname( $short );
    }

    $self->next::method( @_ );
}

1;
