package SixteenColors::Schema::ResultSet::Year;

use strict;
use warnings;

use parent 'DBIx::Class::ResultSet::Data::Pageset';

sub TO_JSON {
    my $self = shift;
    return [
        map { { $_->get_columns } } $self->all
    ]
}

1;
