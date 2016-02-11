package Pdbc::Generator::Template;

use strict;
use warnings FATAL => 'all';

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(ENTITY_TMP REPOSITORY_TMP SERVICE_TMP FOREIGN_TMP);

sub ENTITY_TMP {
	return <<"EOS";
package {{ package }};

use strict;
use warnings;

sub new {
	my \$pkg = shift;
	my \$self = {
		{{# defaults }}
		{{ column }} => "{{{ value }}}",
		{{/ defaults }}
		\@_
	};
	&is_valid(\$self) or die "Faild to instantiation : {{ package }}";
	return bless \$self, ref(\$pkg) || \$pkg;
}

{{# columns }}
sub get_{{ column }} {
	my \$self = shift;
	{{=<% %>=}}
	return \$self->{<% column %>};
	<%={{ }}=%>
}
sub set_{{ column }} {
	my \$self = shift;
	my (\$value) = \@_;
	{{=<% %>=}}
	\$self->{<% column %>} = \$value;
	<%={{ }}=%>
}

{{/ columns }}
sub is_valid {
	my \$self = shift;
	my \@errors = ();
	{{# not_null_columns }}
	{{=<% %>=}}
	defined \$self->{<% column %>} or push \@errors, '<% column %>';
	<%={{ }}=%>
	{{/ not_null_columns }}
	if(\@errors > 0){
		print STDERR join(", ", \@errors) . " IS NOT NULL\\n";
		return undef;
	}
	return 1;
}

1;
EOS
}

sub REPOSITORY_TMP {
	return <<"EOS";
package {{ package }};

use strict;
use warnings;

use Pdbc::PdbcManager;
our \@ISA = qw(Pdbc::PdbcManager);

use Pdbc::Where::Operator;
use {{ entity_package }};
use Scalar::Util;

sub new {
	my \$pkg = shift;
	my \$self = {
		{{# constractor }}
		{{ name }} => '{{ value }}',
		{{/ constractor }}
		\@_
	};
	return bless \$self, ref(\$pkg) || \$pkg;
}

{{# unique_keys }}
sub find_by_{{ column }} {
	my \$self = shift;
	my (\$value) = \@_;
	my \$result = \$self->from('{{ table }}')
		->where('{{ column }}', \$value, EQUAL)
		->get_single_result();
	return {{ entity_package }}->new(%\$result);
}
{{/ unique_keys }}

sub find_all {
	my \$self = shift;
	my (\$options) = \@_;
	my \$result = \$self->from('{{ table }}')
		->get_result_list();
	my \@records;
	while(my \$result = shift \@\$result){
		push \@records, {{ entity_package }}->new(%\$result);
	}
	return \\\@records;
}

sub find_by_condition {
	my \$self = shift;
	my (\$where, \$options) = \@_;
	my \$blessed = Scalar::Util::blessed \$where;
	if(!defined \$blessed || \$blessed ne 'Pdbc::Where'){
		die"引数は Pdbc::Where のインスタンスである必要があります";
	}
	my \$result = \$self->from('{{ table }}')
		->where(\$where)
		->get_result_list();
	my \@records;
	while(my \$result = shift \@\$result){
		push \@records, {{ entity_package }}->new(%\$result);
	}
	return \\\@records;
}

1;
EOS
}

sub SERVICE_TMP {
	return <<"EOS";
package {{ package }};

use strict;
use warnings;

use Exporter;
our \@ISA = qw(Exporter);
our \@EXPORT = qw(get_insert_phrase{{# has_pkey }} get_update_phrase get_delete_phrase{{/ has_pkey }});

use Pdbc::Where;
use Pdbc::Where::Operator;
use {{ entity_package }};
use {{ repository_package }};
{{# foreign_packages }}
use {{ package_name }};
{{/ foreign_packages }}

sub new {
	my \$pkg = shift;
	my \$repository = {{ repository_package }}->new();
	my \$self = {
		repository => \$repository,
		\@_
	};
	return bless \$self, ref(\$pkg) || \$pkg;
}

sub search {
	my \$self = shift;
	\$self->{repository}->connect();
	my (\$where, \$options) = \@_;
	my \${{ table }}s = \$self->{repository}->find_by_condition(\$where, \$options);
	for my \${{ table }}(\@\${{ table }}s){
		{{# foreign_variables }}
		my (\${{ valiable_name }}, \${{ valiable_name }}_repository);
		{{/ foreign_variables }}
{{{ foreign_bind }}}
	}
	\$self->{repository}->disconnect();
	return \${{ table }}s;
}

sub get_insert_phrase {
	my (\$entity) = \@_;
	my \$blessed = Scalar::Util::blessed \$entity;
	if(!defined \$blessed || \$blessed ne '{{ entity_package }}'){
		die"引数は {{ entity_package }} のインスタンスである必要があります";
	}
	my \@columns;
	my \@values;
	while(my (\$column, \$value) = each (\%\$entity)){
		push \@columns, \$column;
		unless(\$value =~ /^.+\\(.*\\)\$/m){
			\$value =~ s/''/'/;
			\$value =~ s/([\\\\|\\\$|\\\@|\\\'|\\\"])/\\\$1/g;
			\$value = "'\$value'";
		}
		push \@values, \$value;
	}
	return "INSERT INTO {{ table }} ( " . join(",", \@columns) . " ) VALUES (" . join(", ", \@values) . ");";
}

{{# has_pkey }}
sub get_update_phrase {
	my (\$entity) = \@_;
	my \$blessed = Scalar::Util::blessed \$entity;
	if(!defined \$blessed || \$blessed ne '{{ entity_package }}'){
		die"引数は {{ entity_package }} のインスタンスである必要があります";
	}
	my \@columns;
	my \@values;
	while(my (\$column, \$value) = each (\%\$entity)){
		push \@columns, \$column;
		unless(\$value =~ /^.+\\(.*\\)\$/m){
			\$value =~ s/''/'/;
			\$value =~ s/([\\\\|\\\$|\\\@|\\\'|\\\"])/\\\$1/g;
			\$value = "'\$value'";
		}
		push \@values, \$value;
	}
	return "UPDATE {{ table }} SET ( " . join(",", \@columns) . " ) VALUES ( " . join(", ", \@values) . ") WHERE{{{ where }}};";
}

sub get_delete_phrase {
	my (\$entity) = \@_;
	my \$blessed = Scalar::Util::blessed \$entity;
	if(!defined \$blessed || \$blessed ne '{{ entity_package }}'){
		die"引数は {{ entity_package }} のインスタンスである必要があります";
	}
	return "DELETE FROM {{ table }} WHERE{{{ where }}};";
}
{{/ has_pkey }}

1;
EOS
}

sub FOREIGN_TMP {
return <<"EOS";

		{{# parent }}
		for \${{{ root }}} (\${{{ parent }}}){
		{{/ parent }}
		\${{ ref_table }}_repository = {{ ref_repository }}->new();
		\${{ ref_table }}_repository->connect();
		\${{ ref_table }} = \${{ ref_table }}_repository->find_by_condition(Pdbc::Where->new('{{ ref_column }}', {{{ ref_value }}}, EQUAL)) if({{{ ref_value }}});
		\${{ ref_table }}_repository->disconnect();
		{{=<% %>=}}
		\$<%& root %>->{<%& ref_table %>} = \$<%& ref_table %>;
		<%={{ }}=%>
		{{# parent }}
		}
		{{/ parent }}
EOS
}

1;