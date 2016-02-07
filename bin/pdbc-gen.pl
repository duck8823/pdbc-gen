#!/usr/bin/perl
#
#
#

=head1 NAME

pdbc-gen.pl - program for generate entity, repository and service

=head1 SYNOPSIS

pdbc-gen.pl perl [-h <host> -p <port>] <database> <output_dir>

=head1 AUTHOR

@duck8823 <duck8823@gmail.com>

=cut

use strict;
use warnings FATAL => 'all';

use Getopt::Std;
our ($opt_h, $opt_p, $opt_f);
getopts('h:p:f');

use Pdbc::Generator;
use Pdbc::Generator::Type;
use Pdbc::Where;

use File::Path;
use Term::ReadKey;

use Test::More;

unless($ARGV[1]){
	print "Usage : perl [-h <HOST> -p <PORT>] <DATABASE> <OUTPUT_DIR>\n";
	exit(-1);
}

my $host = defined $opt_h ? $opt_h : 'localhost';
my $port = defined $opt_p ? $opt_p : 5432;
my $database = $ARGV[0];
push(@INC, $ARGV[1]);

print "Enter Database username : ";
ReadMode "normal";
chomp(my $user = ReadLine 0);
print "Enter Database password : ";
ReadMode "noecho";
chomp(my $password = ReadLine 0);
ReadMode "restore";
print "\n";

my $generator = Pdbc::Generator->new(
	host	=> $host,
	port	=> $port,
	database=> $database,
	user	=> $user,
	password=> $password,
	debug	=> 0
);
$generator->connect();

my $tables = $generator->get_tables();
while(my $table = shift @$tables){
	&generate($table, ENTITY, $generator->from($table)->build_entity());
	&generate($table, REPOSITORY, $generator->from($table)->build_repository());
	&generate($table, SERVICE, $generator->from($table)->build_service());
}
$generator->disconnect();

sub generate {
	my ($table, $type, $class) = @_;
	my $package_name = $generator->from($table)->build_package_name($type);
	my @entity_packages = split("::", $package_name);
	(my $entity_package_dir = $ARGV[1]) =~ s/\/$//;;
	for(my $i = 0; $i < @entity_packages - 1; $i++){
		$entity_package_dir .= "/$entity_packages[$i]";
	}
	mkpath($entity_package_dir);
	my $entity_package_path = $entity_package_dir . "/" . $entity_packages[-1] . ".pm";
	!defined $opt_f && defined -e $entity_package_path and die"既にファイルが存在します.";
	open(FILE, ">$entity_package_path");
	print FILE $class;
	close(FILE);

	use_ok($package_name);
}