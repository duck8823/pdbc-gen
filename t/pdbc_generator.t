use strict;
use warnings FATAL => 'all';

use Test::More;

use_ok('Pdbc::Generator');
my $pdbcManager = Pdbc::Generator->new(
	database=> 'TestHogeHoge',
	from	=> 'foo_bar'
);
isa_ok $pdbcManager, 'Pdbc::Generator';
is $pdbcManager->build_package_name(),  'Test::Hoge::Hoge::FooBar';

done_testing;