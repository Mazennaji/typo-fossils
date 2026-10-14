use strict;
use warnings;
use Test::More tests => 2;

use_ok('Typo::Fossils');
is(Typo::Fossils->version, '0.001', 'version is set');
