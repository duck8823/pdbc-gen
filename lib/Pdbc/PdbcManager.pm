package Pdbc::PdbcManager;

use strict;
use warnings FATAL => 'all';

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw();

use DBI;
use Pdbc::Record;
use Pdbc::Connection;

use Scalar::Util qw(blessed);

sub new {
	my $pkg = shift;
	my $self = {
		@_
	};
	$self->{connection} = Pdbc::Connection->new(%$self) if(!defined $self->{connection});
	&clear_condition($self);
	return bless $self, $pkg;
}

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

sub order {
	my $self = shift;
	my ($column, $order) = @_;
	defined $column && defined $order or die"引数は カラム名, 順序 で指定してください.";
	my $includes = $self->get_columns;
	for my $include (@$includes){
		if($include eq $column){
			$self->{order} = {
				column      => $column,
				asc_or_desc => $order
			};
			return $self;
		}
	}
	die"カラムの指定が間違っています $column";
}

sub distinct {
	my $self = shift;
	$self->{distinct} = 1;
	return $self;
}

sub limit {
	my $self = shift;
	my ($limit) = @_;
	defined $limit && $limit =~ /^\d+$/m or die"引数は整数で指定してください.";
	$self->{limit} = $limit;
	return $self;
}

sub offset {
	my $self = shift;
	my ($offset) = @_;
	defined $offset && $offset =~ /^\d+$/m or die"引数は整数で指定してください.";
	$self->{offset} = $offset;
	return $self;
}

sub build_select_phrase {
	my $self = shift;
	my $left_outer_join = '';
	if(defined $self->{left_outer_join}){
		for(my $i = 0; $i < @{$self->{left_outer_join}}; $i++){
			my $join = ${$self->{left_outer_join}}[$i];
			$left_outer_join .= " LEFT OUTER JOIN " . $join->{table} . " ON " . $join->{where}->get_phrase(value => 0) . " ";
		}
	}
	if(defined $self->{inner_join}){
		for(my $i = 0; $i < @{$self->{inner_join}}; $i++){
			my $join = ${$self->{inner_join}}[$i];
			$left_outer_join .= " INNER JOIN " . $join->{table} . " ON " . $join->{where}->get_phrase(value => 0) . " ";
		}
	}
	my $columns = defined $self->{includes} ? join(", ", @{$self->{includes}}) : join(", ", @{$self->get_columns()});
	$columns = '*' unless($columns);
	my $where  = defined $self->{where}  ? " WHERE "  . $self->{where}->get_phrase() : '';
	my $offset = defined $self->{offset} ? " OFFSET " . $self->{offset}  : '';
	my $limit  = defined $self->{limit}  ? " LIMIT "  . $self->{limit}   : '';
	my $order  = defined $self->{order}  ? " ORDER BY " . $self->{order}->{column} . " " . $self->{order}->{asc_or_desc} : '';

	if($self->{distinct}){
		$columns = "DISTINCT $columns";
	}

	my $sql = "SELECT $columns FROM $self->{from}$left_outer_join$where$order$offset$limit;";
	print STDERR "$sql\n" if($self->{debug});
	return $sql;
}

sub get_single_result {
	my $self = shift;
	my $records = &get_result($self);
	@$records > 1 and die"結果が単一ではありません.";
	my $record = shift @$records;
	return Pdbc::Record->new(%$record);
}

sub get_result_list {
	my $self = shift;
	my $records = &get_result($self);
	my @results;
	while( my $record = shift @$records){
		push @results, Pdbc::Record->new(%$record);
	}
	return \@results;
}

sub get_count {
	my $self = shift;
	my $records = &get_result($self);
	return scalar @$records;
}

sub get_result {
	my $self = shift;
	my $sth = $self->{connection}->{handle}->prepare($self->build_select_phrase());
	$sth->execute();
	my @fields = @{$sth->{NAME}};
	my %fields;
	while(my $field = shift @fields){
		$fields{$field} = 1;
	}
	my $records = $sth->fetchall_arrayref(+{%fields});
	$self->clear_condition();
	return $records;
}

sub get_columns {
	my $self = shift;
	my @col;
	unless(defined $self->{includes}) {
		my @fetch_tables = ( $self->{from} );
		if (defined $self->{left_outer_join}) {
			while(my $left_outer_join = shift @{$self->{left_outer_join}}){
				push @fetch_tables, $left_outer_join->{table};
			}
		}
		if (defined $self->{inner_join}) {
			while(my $inner_join = shift @{$self->{inner_join}}){
				push @fetch_tables, $inner_join->{table};
			}
		}

		while(my $fetch_table = shift @fetch_tables){
			my $sth = $self->{connection}->{handle}->column_info(undef, undef, $fetch_table, undef);
			my $records = $sth->fetchall_arrayref(+{});
			while(my $record = shift @$records){
				push @col, $record->{COLUMN_NAME} if $record->{COLUMN_NAME};
			}
		}
	} else {
		@col = @{$self->{includes}};
	}
	if(defined $self->{excludes}){
		while(my $exclude = shift @{$self->{excludes}}){
			@col = grep $_ ne $exclude, @col;
		}
	}
	return \@col;
}

sub connect {
	my $self = shift;
	$self->{connection}->open;
}

sub disconnect {
	my $self = shift;
	$self->{connection}->close;
}

sub clear_condition {
	my $self = shift;
	delete $self->{from};
	delete $self->{left_outer_join};
	delete $self->{includes};
	delete $self->{excludes};
	delete $self->{where};
	delete $self->{limit};
	delete $self->{offset};
	delete $self->{order};
}

1;