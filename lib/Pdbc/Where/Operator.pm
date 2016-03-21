package Pdbc::Where::Operator;

use strict;
use warnings FATAL => 'all';

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(EQUAL NOT_EQUAL NOT_NULL NULL LIKE);

sub new {
	my $pkg = shift;
	my $self = {
		@_
	};

	return bless $self, $pkg;
}


sub EQUAL {
	return Pdbc::Where::Operator->new(
		operator => "=",
		need_right => 1
	);
}

sub NOT_EQUAL {
	return Pdbc::Where::Operator->new(
		operator => "!=",
		need_right => 1
	);
}

sub NOT_NULL {
	return Pdbc::Where::Operator->new(
		operator => "IS NOT NULL",
		need_right => undef
	);
}

sub NULL {
	return Pdbc::Where::Operator->new(
		operator => "IS NULL",
		need_right => undef
	);
}

sub LIKE {
	return Pdbc::Where::Operator->new(
		operator => "LIKE",
		need_right => 1
	);
}

sub GRATER_THAN {
	return Pdbc::Where::Operator->new(
		operator => ">",
		need_right => 1
	);
}

sub GRATER_EQUAL {
	return Pdbc::Where::Operator->new(
		operator => ">=",
		need_right => 1
	);
}

sub LESS_THAN {
	return Pdbc::Where::Operator->new(
		operator => "<",
		need_right => 1
	);
}

sub LESS_EQUAL {
	return Pdbc::Where::Operator->new(
		operator => "<=",
		need_right => 1
	);
}

sub get_operator {
	my $self = shift;
	return $self->{operator};
}

sub need_right {
	my $self = shift;
	return $self->{need_right};
}

1;