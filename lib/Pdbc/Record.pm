package Pdbc::Record;

use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw();

use Encode;

sub new {
	my $pkg = shift;
	my $self = {
		@_
	};
	return bless $self, $pkg;
}

sub get {
	my $self = shift;
	my ($field) = @_;
	return $self->{$field};
}

sub get_fields {
	my $self = shift;
	my @fields = keys %$self;
	return \@fields;
}

sub to_string {
	my $self = shift;
	my @elems;
	while(my ($key, $val) = each %$self){
		my $elem = " " . $key . " : ";
		$elem .= defined $val ? $val : 'undef';
		$elem .= " ";
		push @elems, $elem;
	}
	return encode('utf8', "{" . join(", ", @elems) . "}");
}

sub equals {
	my $self = shift;
	my ($target) = @_;
	my $blessed = Scalar::Util::blessed $target;
	return defined $blessed && $blessed eq Scalar::Util::blessed $self;
}

1;