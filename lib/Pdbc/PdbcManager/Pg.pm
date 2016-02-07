package Pdbc::PdbcManager::Pg;

use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use Pdbc::PdbcManager;
our @ISA = qw(Pdbc::PdbcManager);
our @EXPORT = qw();

use Pdbc::Where::Operator;
use Pdbc::Record;


sub new {
	my $pkg = shift;
	my $self = {
		database	=> 'postgres',
		host		=> 'localhost',
		port		=> 5432,
		user		=> 'postgres',
		password	=> '',
		@_
	};
	return bless $self, $pkg;
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
	my $sth = $self->{connect}->prepare($self->build_select_phrase());
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
		my $colomn_manager = Pdbc::PdbcManager::Pg->new( %$self );
		$colomn_manager->clear_condition();
		$colomn_manager->connect();

		while(my $fetch_table = shift @fetch_tables){
			my $result = $colomn_manager->from('information_schema.columns')
				->includes('column_name')
				->where( Pdbc::Where->new('table_catalog', $self->{database}, EQUAL )
					->and( Pdbc::Where->new('table_name', $fetch_table, EQUAL ) ) )
				->get_result_list();

			while(my $column = shift @$result){
				push @col, $fetch_table.".".$column->get('column_name');
			}
		}
		$colomn_manager->disconnect();
	} else {
		@col = @{$self->{includes}};
	}
	if(defined $self->{excludes}){
		my @excludes;
		while(my $exclude = shift @{$self->{excludes}}){
			for my $col (@col){
				(my $cond = $col) =~ s/\sAS.*$//;
				push @excludes, $col if($cond eq $exclude);
			}
		}
		while(my $exclude = shift @excludes){
			@col = grep $_ ne $exclude, @col;
		}
	}

	return \@col;
}

sub connect {
	my $self = shift;
	my $dbh = DBI->connect("dbi:Pg:dbname=$self->{database};host=$self->{host};port=$self->{port}",
						  $self->{user},
						  $self->{password},
						  { AutoCommit => 0 }
	) or die"データベースに接続できませんでした.";
	$self->{connect} = $dbh;
}

sub disconnect {
	my $self = shift;
	my $dbh = $self->{connect};
	$dbh->disconnect();
	delete $self->{connect};
}

1;