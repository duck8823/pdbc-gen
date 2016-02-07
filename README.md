# PDBC Manager
S2JDBCライクなPerlのDBIインターフェースを作ってみました.  
Postgresqlで使えます.
  
## quick start
```perl
use Pdbc::PdbcManager::Pg;

my $pdbc_manager = Pdbc::PdbcManager::Pg->new(
	database	=> 'hoge',
	user	=> 'user',
	password	=> 'password'
);
my $records = $pdbc_manager->from('table')
						->get_result_list();
while(my $record = shift @$records){
	print $record->to_string();
}
```
## 使い方
### 一意の結果の取得
```perl
use Pdbc::Where;
use Pdbc::Where::Operator;

my $record = $pdbc_manager->from('table')
						->where(Pdbc::Where->new('id', 1, EQUAL))
						->get_single_result;
print $record->to_string();
```
### 外部結合
```perl
my $records = $pdbc_manager->from('table')
						->left_outer_join('foreign', Pdbc::Where->new('table.foreign_id', 'foreign.id', EQUAL))
						->get_result_list();
while(my $record = shift @$records){
	print $record->to_string();
}

$records = $pdbc_manager->from('table')
						->inner_join('foreign', Pdbc::Where->new('table.foreign_id', 'foreign.id', EQUAL))
						->get_result_list();
while(my $record = shift @$records){
	print $record->to_string();
}
```
### 条件の組み合わせ
```perl
my $records = $pdbc_manager->from('table')
						->where(Pdbc::Where->new('column_1', 'value_1', EQUAL)
						    ->and(Pdbc::Where->new('column_2', IS_NOT_NULL)
						        ->or(Pdbc::Where->new('column_2', '%value_2%', LIKE)))
						    ->and(Pdbc::Where->new('column_3', 'value_3', EQUAL)))
						->get_result_list();
while(my $record = shift @$records){
	print $record->to_string();
}
```
  
  
# pdbc-gen  
データベーススキーマから Entity, Repository, Serviceクラスを自動生成します. 
## Usage
```sh
$ perl -I lib bin\pdbc-gen.pl [-h <host> -p <port>] <database> <target_dir>
```
