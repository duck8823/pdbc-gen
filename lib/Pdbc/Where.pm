package Pdbc::Where;

use strict;
use warnings FATAL => 'all';

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw();

use Pdbc::Where::Operator;
use Scalar::Util;

sub new {
	my $pkg = shift;
	my ($left, $right, $operator);
	if(@_ == 2){
		($left, $operator) = @_;
	} else {
		($left, $right, $operator) = @_;
	}
	my $self = {
		left => $left,
		right => $right,
		operator => $operator
	};
	&is_valid($self) or die"インスタンスの生成に失敗しました.";
	return bless $self, $pkg;
}

sub and {
	my $self = shift;
	my ($where) = @_;
	my $blessed = Scalar::Util::blessed $where;
	if(!defined $blessed || $blessed ne 'Pdbc::Where'){
		die"引数は Pdbc::Where のインスタンスである必要があります.";
	}
	push @{$self->{and}}, $where;
	return $self;
}

sub or {
	my $self = shift;
	my ($where) = @_;
	my $blessed = Scalar::Util::blessed $where;
	if(!defined $blessed || $blessed ne 'Pdbc::Where'){
		die"引数は Pdbc::Where のインスタンスである必要があります.";
	}
	push @{$self->{or}}, $where;
	return $self;
}

sub get_phrase {
	my $self = shift;
	my $args = {
		value => 1,
		@_
	};
	&is_valid($self) or die"Where句の生成に失敗しました.";
	my $where = $self->{left} . " " . $self->{operator}->get_operator();
	my $escape = $args->{value} ? "'" : "";
	defined $self->{operator}->need_right() and $where .= " $escape" . $self->{right} . "$escape";
	if(defined $self->{and}){
		my $and_phrase;
		while(my $formula = shift @{$self->{and}}){
			$and_phrase .= " AND ". $formula->get_phrase();
		}
		$and_phrase =~ s/^\sAND\s//;
		$where = "(" . $where . " AND " . $and_phrase . ") ";
	}
	if(defined $self->{or}){
		my $or_phrase;
		while(my $formula = shift @{$self->{or}}){
			$or_phrase .= " OR " . $formula->get_phrase();
		}
		$or_phrase =~ s/^\sOR\s//;
		$where = "(" . $where . " OR " . $or_phrase . ") ";
	}
	return $where;
}

sub is_valid {
	my $self = shift;
	my @errors;
	defined $self->{left} or push @errors, "left";
	if(defined $self->{operator} && defined $self->{operator}->need_right() && !defined $self->{right}){
		push @errors, "right";
	}
	my $blessed = $self->{operator} ? Scalar::Util::blessed $self->{operator} : '';
	defined $blessed && $blessed eq 'Pdbc::Where::Operator' or push @errors, "operator";
	if(@errors > 0){
		print STDERR "引数は 左辺, 右辺, 演算子(Pdbc::Where::Operator) または 左辺, 演算子(Pdbc::Where::Operator) で指定してください.\n";
		return undef;
	}
	return 1;
}

1;