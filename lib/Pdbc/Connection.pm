package Pdbc::Connection;

use strict;
use warnings;

our @ISA = qw(Exporter);
our @EXPORT = qw();

use DBI;
use Data::Dumper;

sub new {
	my $pkg = shift;
	my $self = {
		driver		=> 'Pg',
		database	=> 'postgres',
		host		=> 'localhost',
		port		=> 5432,
		user		=> 'postgres',
		password	=> '',
		@_
	};
	return bless $self, $pkg;
}

sub open {
	my $self = shift;
	my $dbh = DBI->connect("dbi:$self->{driver}:dbname=$self->{database};host=$self->{host};port=$self->{port}",
		$self->{user},
		$self->{password},
		{ AutoCommit => 0 }
	) or die"データベースに接続できませんでした.";
	$self->{handle} = $dbh;
}

sub close {
	my $self = shift;
	$self->{handle}->disconnect();
	delete $self->{handle};
}

1;