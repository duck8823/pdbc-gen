package Pdbc::Generator::Type;

use strict;
use warnings FATAL => 'all';

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(ENTITY SERVICE REPOSITORY);

sub ENTITY {
	return { package => 'Entity', surfix => '' };
}

sub SERVICE {
	return { package => 'Service', surfix => 'Service' };
}

sub REPOSITORY {
	return { package => 'Repository', surfix => 'Repository' };
}

1;