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
  
  
# pdbc-gen  
データベーススキーマから Entity, Repository, Serviceクラスを自動生成します. 
## Usage
```sh
$ perl -I lib bin\pdbc-gen.pl [-h <host> -p <port>] <database> <target_dir>
```

## 生成されるクラス
### Entity
コンストラクタでデフォルト値, NULLチェック  
ゲッター, セッター
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
  
find_by_ユニークカラム - 一意検索  
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

sub find_by_ユニークカラム {
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
