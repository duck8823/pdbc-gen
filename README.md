# PDBC Manager
S2JDBCライクなPerlのDBIインターフェースを作ってみました.  
  
## quick start
```perl
use Pdbc::PdbcManager;

my $pdbc_manager = Pdbc::PdbcManager->new(
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
### カラムの指定
#### 指定したカラムだけを取得する.
```perl
my $records = $pdbc_manager->from('table')
						->includes('column_1','column_2')
						->get_result_list();
while(my $record = shift @$records){
	print $record->to_string();
}
```
#### 指定したカラムを除外する.
```perl
my $records = $pdbc_manager->from('table')
						->excludes('column_1','column_2')
						->get_result_list();
while(my $record = shift @$records){
	print $record->to_string();
}
```
includes()とexcludes()は一緒に使えません.  
includes()が優先されます.  
### 順序、範囲  
#### order by
```perl
my $records = $pdbc_manager->from('table')
						->order("column", "ASC")
						->get_result_list();
```  
#### offset
```perl
my $records = $pdbc_manager->from('table')
						->offset(10)
						->get_result_list();
```  
#### limit
```perl
my $records = $pdbc_manager->from('table')
						->limit(1)
						->get_result_list();
```  
  
  
# pdbc-gen  
データベーススキーマから Entity, Repository, Serviceクラスを自動生成します. 
## Usage
```sh
$ perl -I lib bin\pdbc-gen.pl [-h <host> -p <port>] <database> <target_dir>
```

## 生成されるクラス
### Entity
コンストラクタでデフォルト値, NULL, 型チェック  
ゲッター, セッター（型チェック）
```perl
package Foo::Entity::Bar; # データベース名::Entity::テーブル名

sub new {
	my $pkg = shift;
	my $self = {
		id => "デフォルト値", # 各カラムのデフォルト値
		@_
	};
	&is_valid($self) or die "Faild to instantiation : Foo::Entity::Bar";
	return bless $self, ref($pkg) || $pkg;
}

sub get_カラム名 {
	my $self = shift;
	return $self->{foo};
}
sub set_カラム名 {
	my $self = shift;
	my ($value) = @_;
	# 数値カラムの場合、数値チェック
	$self->{foo} = $value;
}

# NOT NULL制約付きカラムのチェック
sub is_valid {
	my $self = shift;
	my @errors = ();
	defined $self->{foo} or push @errors, 'foo';
	if(@errors > 0){
		print STDERR join(", ", @errors) . " IS NOT NULL\n";
		return undef;
	}
	return 1;
}
```
  
### Repository
UNIQUEカラムでの一意検索, 全レコードの取得 および 条件検索  
書くレコードは対応するエンテティのインスタンスとして返される.  
  
find_by_プライマリキー - 一意検索  
find_all - 全レコードの取得  
find_by_condition - 条件検索
```perl
package Hoge::Repository::HogeRepository; # データベース名::Repository::テーブル名Repository

# 生成時のデータベース接続設定でコンストラクタを生成
sub new {
	my $pkg = shift;
	my $self = {
		host => 'localhost',
		port => '5432',
		database => 'hoge',
		user => 'user',
		password => '',
		@_
	};
	return bless $self, ref($pkg) || $pkg;
}

sub find_by_プライマリキー {
	...
	return Hoge::Entity::Hoge->new(%$result);
}

sub find_all {
	...
	return \@records;
}

sub find_by_condition {
	...
	return \@records;
}
```
### Service
search - 外部キーを結合してレコードを取得する.  
get_insert_phrase - INSERT 文  
get_delete_phrase - プライマリキーによる UPDATE 文  
get_delete_phrase - プライマリキーによる DELETE 文  
```perl
package Hoge::Service::HogeService; # データベース名::Service::テーブル名

# 外部結合も取得する
sub search {
	...
	return \@records;
}

sub get_insert_phrase {
	my ($entity) = @_;
	...
	return "INSERT文";
}

sub get_update_phrase {
	my ($entity) = @_;
	...
	return "UPDATE文 WHERE プライマリキー";
}

sub get_delete_phrase {
	my ($entity) = @_;
	return "DELETE文 FROM hoge WHERE プライマリキー";
}
```
  
  
## 生成されたソースの利用例
エンティティオブジェクトの生成とINSERT文の組み立て
```perl
use Hoge::Enyity::FooBar;
use Hoge::Service::FooBarService qw(get_insert_phrase);

my $entity = Hoge::Entity::FooBar->new(
	column_1 => 'hoge_1',
	column_2 => 'hoge_2'
);

print get_insert_phrase($entity) . "\n";
```
  
```sh
INSERT INTO foo_bar (primary_key, column_1, column_2) VALUES ('default_value', 'hoge_1', 'hoge_2');
```
  
  
条件による検索とUPDATE文の組み立て
```perl
use Pdbc::Where;
use Pdbc::Where::Operator;

use Hoge::Service::FooBarService qw(get_update_phrase);

my $foo_bar_service = Hoge::Service::FooBarService->new();
my $entities = $foo_bar_service->search(Pdbc::Where->new('column_1', 'hoge_1', EQUAL));
for my $entity (@$entities){
	$entity->set_column_1('foo_1');
	print get_update_phrase($entity);
}
```
```sh
UPDATE foo_bar SET (primary_key, column_1, column_2) VALUES ('default_value', 'foo_1', 'hoge_2') WHERE primary_key = 'default_value';
```
