package Pdbc::PdbcManager;

use strict;
use warnings FATAL => 'all';

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw();

use DBI;
use Scalar::Util qw(blessed);

sub from {
	my $self = shift;
	my ($from) = @_;
	$self->{from} = $from;
	return $self;
}

sub inner_join {
	my $self = shift;
	my ($table, $where) = @_;
	my $blessed = Scalar::Util::blessed $where;
	if(!defined $blessed || $blessed ne 'Pdbc::Where'){
		die"第二引数は Pdbc::Where のインスタンスである必要があります";
	}
	my @join = defined $self->{inner_join} ? @{$self->{inner_join}} : ();
	push @join, {table => $table, where => $where};
	$self->{inner_join} = \@join;
	return $self;
}

sub left_outer_join {
	my $self = shift;
	my ($table, $where) = @_;
	my $blessed = Scalar::Util::blessed $where;
	if(!defined $blessed || $blessed ne 'Pdbc::Where'){
		die"第二引数は Pdbc::Where のインスタンスである必要があります";
	}
	my @join = defined $self->{left_outer_join} ? @{$self->{left_outer_join}} : ();
	push @join, {table => $table, where => $where};
	$self->{left_outer_join} = \@join;
	return $self;
}

sub includes {
	my $self = shift;
	my (@columns) = @_;
	$self->{includes} = \@columns;
	return $self;
}

sub excludes {
	my $self = shift;
	my (@columns) = @_;
	$self->{excludes} = \@columns;
	return $self;
}

sub where {
	my $self = shift;
	my ($where) = @_;
	my $blessed = Scalar::Util::blessed $where;
	if(!defined $blessed || $blessed ne 'Pdbc::Where'){
		die"引数は Pdbc::Where のインスタンスである必要があります";
	}
	$self->{where} = $where;
	return $self;
}

sub build_select_phrase {
	my $self = shift;
	my $left_outer_join = '';
	if(defined $self->{left_outer_join}){
		for(my $i = 0; $i < @{$self->{left_outer_join}}; $i++){
			my $join = ${$self->{left_outer_join}}[$i];
			$left_outer_join .= "LEFT OUTER JOIN " . $join->{table} . " ON " . $join->{where}->get_phrase(value => 0) . " ";
		}
	}
	if(defined $self->{inner_join}){
		for(my $i = 0; $i < @{$self->{inner_join}}; $i++){
			my $join = ${$self->{inner_join}}[$i];
			$left_outer_join .= "INNER JOIN " . $join->{table} . " ON " . $join->{where}->get_phrase(value => 0) . " ";
		}
	}
	my $columns = defined $self->{includes} ? join(", ", @{$self->{includes}}) : join(", ", @{$self->get_columns()});
	$columns = '*' unless($columns);
	my $where = defined $self->{where} ? "WHERE " . $self->{where}->get_phrase() : '';
	print STDERR "SELECT $columns FROM $self->{from} $left_outer_join $where\n" if($self->{debug});
	return "SELECT $columns FROM $self->{from} $left_outer_join $where;";
}

sub clear_condition {
	my $self = shift;
	delete $self->{from};
	delete $self->{left_outer_join};
	delete $self->{includes};
	delete $self->{excludes};
	delete $self->{where};
}


1;