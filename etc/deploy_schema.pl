#!/usr/bin/perl

use strict;
use warnings;

use lib 'lib';

use SixteenColors;

my $schema = SixteenColors->model( 'DB' )->schema;
$schema->deploy;
$schema->journal_schema_deploy;
