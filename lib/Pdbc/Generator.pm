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
	my @tables;
	my $sth = $self->{connect}->table_info(undef, "public", undef, "TABLE");
	my $records = $sth->fetchall_arrayref(+{}) if defined($sth);
	while(my $record = shift @$records){
		push @tables, $record->{TABLE_NAME};
	}
	return \@tables;
}

sub get_columns_info {
	my $self = shift;
	my @columns_info;
	my $sth = $self->{connect}->column_info(undef, undef, $self->{from}, undef);
	my $columns = $sth->fetchall_arrayref(+{});
	for my $column (@$columns){
		my $is_integer = ($column->{TYPE_NAME} =~ /.*(int|serial).*/m);
		my $is_point = ($column->{TYPE_NAME} =~ /.*(demical|numeric|real|double|float).*/m);
		my $column_info = {
			table_name		=> $column->{TABLE_NAME},
			column_name		=> $column->{COLUMN_NAME},
			column_default	=> $column->{COLUMN_DEF},
			is_nullable		=> $column->{NULLABLE},
			is_integer		=> $is_integer,
			is_point		=> $is_point,
			type			=> $column->{TYPE_NAME}
		};
		push @columns_info, $column_info;
	}
	return \@columns_info;
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
		push @defaults, { column => $column_info->{column_name}, value => $value};
	}
	return \@defaults;
}

sub get_not_null_columns {
	my $self = shift;

	my @columns;
	my $columns_info = $self->get_columns_info();
	while(my $column_info = shift @$columns_info ){
		push @columns, { column => $column_info->{column_name} } unless($column_info->{is_nullable});
	}
	return \@columns;
}

sub get_integer_columns {
	my $self = shift;

	my @columns;
	my $columns_info = $self->get_columns_info();
	while(my $column_info = shift @$columns_info ){
		push @columns, { column => $column_info->{column_name} } if($column_info->{is_integer});
	}
	return \@columns;
}

sub get_point_number_columns {
	my $self = shift;

	my @columns;
	my $columns_info = $self->get_columns_info();
	while(my $column_info = shift @$columns_info ){
		push @columns, { column => $column_info->{column_name} } if($column_info->{is_point});
	}
	return \@columns;
}

sub get_all_columns {
	my $self = shift;

	my @columns;
	my $columns_info = $self->get_columns_info();
	while(my $column_info = shift @$columns_info ){
		push @columns, { column => $column_info->{column_name}, is_nullable => $column_info->{is_nullable}, is_integer => $column_info->{is_integer} };
	}
	return \@columns;
}

sub get_foreign_keys {
	my $self = shift;
	my ($current_loop) = @_;
	$current_loop = 1 unless($current_loop);
	my $result;
	my $sth = $self->{connect}->foreign_key_info(undef, undef, undef, undef, undef, $self->{from});
	my $records = $sth->fetchall_arrayref(+{}) if defined($sth);
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
			my $ref_foreign_keys = $self->from($ref->{table_name})->get_foreign_keys($current_loop);
			$ref->{foreign_keys} = $ref_foreign_keys;
		}
		$foreign_key->{ref} = $ref;
		push @forein_keys, $foreign_key;
	}
	return \@forein_keys;
}

sub get_primary_keys {
	my $self = shift;

	my @primary_keys;
	my $sth = $self->{connect}->primary_key_info(undef, undef, $self->{from});
	return \@primary_keys unless($sth);
	my $records = $sth->fetchall_arrayref(+{});
	while( my $record = shift @$records){
		push @primary_keys, {column => $record->{COLUMN_NAME}};
	}
	return \@primary_keys;
}

sub build_entity {
	my $self = shift;

	my $package = $self->build_package_name(ENTITY);
	my $defaults = $self->get_default_values();
	my $not_nulls = $self->get_not_null_columns();
	my $columns = $self->get_all_columns();
	my $integers = $self->get_integer_columns();
	my $points = $self->get_point_number_columns();

	my $mustache = Template::Mustache->new();
	return $mustache->render(ENTITY_TMP, {
			package		=> $package,
			defaults	=> $defaults,
			not_null_columns => $not_nulls,
			integer_columns => $integers,
			point_number_columns => $points,
			columns		=> $columns
		});
}

sub build_repository {
	my $self = shift;

	my $package = $self->build_package_name(REPOSITORY);
	my $constractor = [
		{name => 'driver', value => $self->{driver}},
		{name => 'host', value => $self->{host}},
		{name => 'port', value => $self->{port}},
		{name => 'database', value=> $self->{database}},
		{name => 'user', value => $self->{user}},
		{name => 'password', value => $self->{password}}
	];

	my $mustache = Template::Mustache->new();
	return $mustache->render(REPOSITORY_TMP, {
			package		=> $package,
			constractor	=> $constractor,
			primary_keys	=> $self->get_primary_keys(),
			table		=> $self->{from},
			entity_package => $self->build_package_name(ENTITY)
		});
}

sub build_service {
	my $self = shift;

	my $package = $self->build_package_name(SERVICE);
	my $repository_package = $self->build_package_name(REPOSITORY);
	my $entity_package = $self->build_package_name(ENTITY);

	my $foreign_keys = $self->get_foreign_keys();
	my $foreign_packages;
	for my $foreign_key (@$foreign_keys){
		my $ref_table = $foreign_key->{ref}->{table_name};
		my $package_name = &build_package_name({database => $self->{database}, from => $ref_table}, REPOSITORY );
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
		my $ref_repository = &build_package_name({database => $self->{database}, from => $ref_table}, REPOSITORY);
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