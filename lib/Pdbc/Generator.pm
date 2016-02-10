package Pdbc::Generator;

use strict;
use warnings FATAL => 'all';

use Pdbc::PdbcManager;
our @ISA = qw(Pdbc::PdbcManager);
our @EXPORT = qw();

use Pdbc::Where::Operator;
use Pdbc::Generator::Template;
use Pdbc::Generator::Type;
use Template::Mustache;
use List::MoreUtils;

sub get_tables {
	my $self = shift;
	my $table_manager = Pdbc::Generator->new(%$self);
	$table_manager->clear_condition();
	$table_manager->connect();
	my @tables;
	my $result = $table_manager->from('information_schema.tables')
					->includes('table_name')
					->where(Pdbc::Where->new('table_schema', 'public', EQUAL)
						->and(Pdbc::Where->new('table_type', 'BASE TABLE', EQUAL)))
					->get_result_list();
	$table_manager->disconnect();
	while(my $table = shift @$result){
		push @tables, $table->get('table_name');
	}
	$self->clear_condition();
	return \@tables;
}

sub get_columns_info {
	my $self = shift;
	my $constraint_manager = Pdbc::Generator->new(%$self);
	$constraint_manager->clear_condition();
	$constraint_manager->connect();
	my $result = $constraint_manager->from('INFORMATION_SCHEMA.COLUMNS')
					->includes('table_name', 'column_name', 'column_default', 'is_nullable', 'data_type')
					->where(Pdbc::Where->new('table_schema', 'public', EQUAL)
						->and(Pdbc::Where->new('table_name', $self->{from}, EQUAL)))
					->get_result_list();
	$constraint_manager->disconnect();
	return $result;
}

sub build_package_name {
	my $self = shift;
	my ($type) = @_;
	(my $package = $self->{database}) =~ s/([A-Z])/::$1/g;
	$package =~ s/^:://;
	$package =~ s/^([a-z])/\u$1/;
	(my $class = $self->{from}) =~ s/(_|^)(.)/\u$2/g;
	return "$package\::$type->{package}\::$class$type->{surfix}";
}

sub get_default_values {
	my $self = shift;

	my @defaults;
	my $columns_info = $self->get_columns_info();
	while(my $column_info = shift @$columns_info ){
		defined $column_info->{column_default} or next;
		my $value = $column_info->{column_default};
		unless($value =~ /^.+\(.*\)$/m){
			$value =~ s/''/'/;
			$value =~ s/([\\|\$|\@|\'|\"])/\\$1/g;
			$value = "'$value'";
		}
		push @defaults, { column => $column_info->{column_name}, value => $value};
	}
	return \@defaults;
}

sub get_not_null_columns {
	my $self = shift;

	my @columns;
	my $columns_info = $self->get_columns_info();
	while(my $column_info = shift @$columns_info ){
		push @columns, { column => $column_info->{column_name} } if($column_info->{is_nullable} eq 'NO');
	}
	return \@columns;
}

sub get_all_columns {
	my $self = shift;

	my @columns;
	my $columns_info = $self->get_columns_info();
	while(my $column_info = shift @$columns_info ){
		push @columns, { column => $column_info->{column_name} };
	}
	return \@columns;
}

sub get_foreign_keys {
	my $self = shift;
	my ($current_loop) = @_;
	$current_loop = 1 unless($current_loop);
	my $foreign_manager = Pdbc::Generator->new(
		%$self
	);
	$foreign_manager->clear_condition();
	$foreign_manager->connect();

	my $result;
	my $dbh = DBI->connect("dbi:Pg:dbname=$self->{database};host=$self->{host};port=$self->{port}",
						  $self->{user},
						  $self->{password},
						  { AutoCommit => 0 }
	);
	my $sth = $dbh->foreign_key_info(undef, undef, undef, undef, undef, $self->{from});
	my $records = $sth->fetchall_arrayref(+{}) if defined($sth);
	$dbh->disconnect();
	while(my $record = shift @$records){
		push @$result, Pdbc::Record->new(
				constraint_name	=> $record->{FK_NAME},
				table_name		=> $record->{FK_TABLE_NAME},
				column_name		=> $record->{FK_COLUMN_NAME},
				unique_constraint_name => $record->{UK_NAME},
				ref => {
					constraint_name	=> $record->{UK_NAME},
					table_name		=> $record->{UK_TABLE_NAME},
					column_name		=> $record->{UK_COLUMN_NAME}
				}
			);
	}
	$current_loop++;
	my @forein_keys;
	while(my $foreign_key = shift @$result){
		my $ref = $foreign_key->{ref};
		if(defined $ref && $foreign_key->{table_name} ne $ref->{table_name} && $current_loop <= 2){
			my $ref_foreign_keys = $foreign_manager->from($ref->{table_name})->get_foreign_keys($current_loop);
			$ref->{foreign_keys} = $ref_foreign_keys;
		}
		$foreign_key->{ref} = $ref;
		push @forein_keys, $foreign_key;
	}
	$foreign_manager->disconnect();
	return \@forein_keys;
}

sub get_unique_keys {
	my $self = shift;
	my $unique_manager = Pdbc::Generator->new(
		%$self
	);
	$unique_manager->clear_condition();
	$unique_manager->connect();
	my $result = $unique_manager->from('information_schema.table_constraints')
		->includes('information_schema.key_column_usage.table_name', 'information_schema.key_column_usage.column_name')
		->left_outer_join('information_schema.key_column_usage', Pdbc::Where->new('information_schema.table_constraints.constraint_name', 'information_schema.key_column_usage.constraint_name', EQUAL))
		->where(Pdbc::Where->new('information_schema.table_constraints.constraint_schema', 'public', EQUAL)
			->and(Pdbc::Where->new('information_schema.table_constraints.constraint_type', 'UNIQUE KEY', EQUAL)
				->or(Pdbc::Where->new('information_schema.table_constraints.constraint_type', 'PRIMARY KEY', EQUAL)))
			->and(Pdbc::Where->new('information_schema.table_constraints.table_name', $self->{from}, EQUAL)))
		->get_result_list();
	my @unique_keys;
	while(my $record = shift @$result){
		push @unique_keys, { column => $record->{'column_name'}};
	}
	$unique_manager->disconnect();
	return \@unique_keys;
}

sub get_primary_keys {
	my $self = shift;

	my $primary_manager = Pdbc::Generator->new(
		%$self
	);
	$primary_manager->clear_condition();
	$primary_manager->connect();
	my $result = $primary_manager->from('information_schema.table_constraints')
		->includes('information_schema.key_column_usage.table_name', 'information_schema.key_column_usage.column_name')
		->left_outer_join('information_schema.key_column_usage', Pdbc::Where->new('information_schema.table_constraints.constraint_name', 'information_schema.key_column_usage.constraint_name', EQUAL))
		->where(Pdbc::Where->new('information_schema.table_constraints.constraint_schema', 'public', EQUAL)
			->and(Pdbc::Where->new('information_schema.table_constraints.constraint_type', 'PRIMARY KEY', EQUAL))
			->and(Pdbc::Where->new('information_schema.table_constraints.table_name', $self->{from}, EQUAL)))
		->get_result_list();
	my @primary_keys;
	while(my $record = shift @$result){
		push @primary_keys, { column => $record->{'column_name'}};
	}
	$primary_manager->disconnect();
	return \@primary_keys;
}

sub build_entity {
	my $self = shift;

	my $package = $self->build_package_name(ENTITY);
	my $defaults = $self->get_default_values();
	my $not_nulls = $self->get_not_null_columns();
	my $columns = $self->get_all_columns();

	my $mustache = Template::Mustache->new();
	return $mustache->render(ENTITY_TMP, {
			package		=> $package,
			defaults	=> $defaults,
			not_null_columns => $not_nulls,
			columns		=> $columns
		});
}

sub build_repository {
	my $self = shift;

	my $package = $self->build_package_name(REPOSITORY);
	my $constractor = [
		{name => 'host', value => $self->{host}},
		{name => 'port', value => $self->{port}},
		{name => 'database', value=> $self->{database}},
		{name => 'user', value => $self->{user}},
		{name => 'password', value => $self->{password}}
	];
	my $unique_keys = $self->get_unique_keys();
	my $table = $self->{from};
	my $entity_package = $self->build_package_name(ENTITY);

	my $mustache = Template::Mustache->new();
	return $mustache->render(REPOSITORY_TMP, {
			package		=> $package,
			constractor	=> $constractor,
			unique_keys	=> $unique_keys,
			table		=> $table,
			entity_package => $entity_package
		});
}

sub build_service {
	my $self = shift;

	my $package = $self->build_package_name(SERVICE);
	my $foreign_keys = $self->get_foreign_keys();
	my $foreign_packages;
	for my $foreign_key (@$foreign_keys){
		my $ref_table = $foreign_key->{ref}->{table_name};
		my $package_name = Pdbc::Generator->new( %$self )->from( $ref_table )->build_package_name( REPOSITORY );
		$foreign_packages->{$package_name} = { package_name => $package_name};
	}
	my $uniq_names = &unique_foreign_table($foreign_keys);
	my $foreign_valiables;

	while(my $uniq_name = shift @$uniq_names){
		push @$foreign_valiables, { valiable_name => $uniq_name };
	}

	my @foreign_packages = values %$foreign_packages;
	my $foreign_bind = $self->build_foreign_bind($self->{from}, $foreign_keys);

	my $primary_keys = $self->get_primary_keys();
	my $has_pkey = @$primary_keys > 0 ? 1 : undef;
	my $where = '';
	while(my $primary_key = shift @$primary_keys){
		$where .= " AND " . $primary_key->{column} . " = " . "\$entity->{$primary_key->{column}}";
	}
	$where =~ s/^\sAND//;

	my $repository_package = $self->build_package_name(REPOSITORY);
	my $entity_package = $self->build_package_name(ENTITY);

	my $mustache = Template::Mustache->new();
	return $mustache->render(SERVICE_TMP, {
			package		=> $package,
			has_pkey	=> $has_pkey,
			where		=> $where,
			table		=> $self->{from},
			foreign_bind=> $foreign_bind,
			entity_package => $entity_package,
			repository_package => $repository_package,
			foreign_packages => \@foreign_packages,
			foreign_variables => $foreign_valiables
		});
}

sub build_foreign_bind {
	my $self = shift;
	my $bind = '';
	my $mutache = Template::Mustache->new();
	my ($root, $foreign_keys, $parent) = @_;
	my @binded;
	for my $foreign_key (@$foreign_keys){
		my $ref_table = $foreign_key->{ref}->{table_name};
		my $ref_repository = Pdbc::Generator->new( %$self )->from( $ref_table )->build_package_name( REPOSITORY );
		unless (grep { $_ eq $ref_repository } @binded) {
			$bind .= $mutache->render( FOREIGN_TMP, {
					root           => $root,
					ref_table      => $ref_table,
					ref_repository => $ref_repository,
					ref_column     => $ref_table.".".$foreign_key->{ref}->{column_name},
					ref_value      => "\$$root\->{$foreign_key->{column_name}}",
					parent         => $parent
				} );
			push @binded, $ref_repository;
		}
		my $ref_foreign_keys = $foreign_key->{ref}->{foreign_keys};
		if(defined $ref_foreign_keys){
			$bind .= $self->build_foreign_bind($ref_table, $ref_foreign_keys, "$root\->{$ref_table}");
		}
	}
	return $bind;
}

sub unique_foreign_table {
	my ($foreign_keys, $arr) = @_;
	for my $foreign_key (@$foreign_keys){
		push @$arr, $foreign_key->{ref}->{table_name};
		my $ref_foreign_keys = $foreign_key->{ref}->{foreign_keys};
		if(defined $ref_foreign_keys){
			&unique_foreign_table($ref_foreign_keys, $arr);
		}
	}
	@$arr = List::MoreUtils::uniq @$arr;
	return $arr;
}

1;