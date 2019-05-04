# Simple module for handling some math operations
# Update history: 
#	26/08/2012 - fix for new fail() syntax
#################################################
package stkutils::math;
use strict;
sub create {
	my $package = shift;
	my $class = shift;
	my $self = {};
	bless $self, $class;
	$self->new(@_);
	return $self;
}
#######################################################
package vector;
use strict;
sub new {
	my ($self, $length) = @_;
	for (my $i = 0; $i < $length; $i++) {
		$self->{$i} = 0;
	}
}
sub set {
	my $self = shift;
	$self->{0} = $_[0];
	$self->{1} = $_[1];
	$self->{2} = $_[2];
}
sub get {return $_[0]->{0}, $_[0]->{1}, $_[0]->{2}}
####################################################
package matrix;
use strict;
sub new {
	my ($self, $row, $column) = @_;
	for (my $i = 0; $i < $row; $i++) {
		$self->{$i} = {};
		for (my $j = 0; $j < $column; $j++) {
			$self->{$i}{$j} = 0;
		}
	}
}
sub set_xyz_i {
	my $self = shift;
	my ($x, $y, $z);
	if ($#_ == 0) {
		$self->set_xyz_i($_[1]->{0}, $_[1]->{1}, $_[1]->{2});
	}
	my $sh = sin($_[1]);
	my $ch = cos($_[1]);
	my $sp = sin($_[2]);
	my $cp = cos($_[2]);
	my $sb = sin($_[3]);
	my $cb = cos($_[3]);

	$self->{1}{1} = $ch*$cb - $sh*$sp*$sb;
	$self->{1}{2} = -$cp*$sb;
	$self->{1}{3} = $ch*$sb*$sp + $sh*$cb;
	$self->{1}{4} = 0;

	$self->{2}{1} = $sp*$sh*$cb + $ch*$sb;
	$self->{2}{2} = $cb*$cp;
	$self->{2}{3} = $sh*$sb - $sp*$ch*$cb;
	$self->{2}{4} = 0;

	$self->{3}{1} = -$cp*$sh;
	$self->{3}{2} = $sp;
	$self->{3}{3} = $ch*$cp;
	$self->{3}{4} = 0;

	$self->{4}{1} = 0;
	$self->{4}{2} = 0;
	$self->{4}{3} = 0;
	$self->{4}{4} = 1;
}
sub get_xyz_i {
	my $self = shift;
	my ($h, $p, $b);
	
	my $cy = sqrt($self->{1}{2}*$self->{1}{2} + $self->{2}{2}*$self->{2}{2});
	if ($cy > 16E-53) {
		$h = -atan2($self->{3}{1}, $self->{3}{3});
		$p = -atan2(-$self->{3}{2}, $cy);
		$b = -atan2($self->{1}{2}, $self->{2}{2});
	} else {
		$h = -atan2(-$self->{1}{3}, $self->{1}{1});
		$p = -atan2(-$self->{3}{2}, $cy);
		$b = 0;
	}
	return $h, $p, $b;
}
sub set_row_4 {
	my $self = shift;
	if ($#_ == 0) {
		$self->set_row_4($_[1]->{'0'}, $_[1]->{'1'}, $_[1]->{'2'});
	}
	$self->{4}{1} = $_[1];
	$self->{4}{2} = $_[2];
	$self->{4}{3} = $_[3];
}
sub invert_43 {
	my $self = shift;
	my ($m) = @_;
	my $cf1 = $m->{2}{2}*$m->{3}{3} - $m->{2}{3}*$m->{3}{2};
	my $cf2 = $m->{2}{1}*$m->{3}{3} - $m->{2}{3}*$m->{3}{1};
	my $cf3 = $m->{2}{1}*$m->{3}{2} - $m->{2}{2}*$m->{3}{1};
	my $det = $m->{1}{1}*$cf1 - $m->{1}{2}*$cf2 + $m->{1}{3}*$cf3;

	$self->{1}{1} = $cf1/$det;
	$self->{2}{1} =-$cf2/$det;
	$self->{3}{1} = $cf3/$det;

	$self->{1}{2} =-($m->{1}{2}*$m->{3}{3} - $m->{1}{3}*$m->{3}{2})/$det;
	$self->{1}{3} = ($m->{1}{2}*$m->{2}{3} - $m->{1}{3}*$m->{2}{2})/$det;
	$self->{1}{4} = 0;

	$self->{2}{2} = ($m->{1}{1}*$m->{3}{3} - $m->{1}{3}*$m->{3}{1})/$det;
	$self->{2}{3} =-($m->{1}{1}*$m->{2}{3} - $m->{1}{3}*$m->{2}{1})/$det;
	$self->{2}{4} = 0;

	$self->{3}{2} =-($m->{1}{1}*$m->{3}{2} - $m->{1}{2}*$m->{3}{1})/$det;
	$self->{3}{3} = ($m->{1}{1}*$m->{2}{2} - $m->{1}{2}*$m->{2}{1})/$det;
	$self->{3}{4} = 0;

	$self->{4}{1} =-($m->{4}{1}*$self->{1}{1} + $m->{4}{2}*$self->{2}{1} + $m->{4}{3}*$self->{3}{1});
	$self->{4}{2} =-($m->{4}{1}*$self->{1}{2} + $m->{4}{2}*$self->{2}{2} + $m->{4}{3}*$self->{3}{2});
	$self->{4}{3} =-($m->{4}{1}*$self->{1}{3} + $m->{4}{2}*$self->{2}{3} + $m->{4}{3}*$self->{3}{3});
	$self->{4}{4} = 1;
}
sub mul_43 {
	my $self = shift;
	my ($m1, $m2) = @_;
	$self->{1}{1} = $m1->{1}{1}*$m2->{1}{1} + $m1->{2}{1}*$m2->{1}{2} + $m1->{3}{1}*$m2->{1}{3};
	$self->{1}{2} = $m1->{1}{2}*$m2->{1}{1} + $m1->{2}{2}*$m2->{1}{2} + $m1->{3}{2}*$m2->{1}{3};
	$self->{1}{3} = $m1->{1}{3}*$m2->{1}{1} + $m1->{2}{3}*$m2->{1}{2} + $m1->{3}{3}*$m2->{1}{3};
	$self->{1}{4} = 0;

	$self->{2}{1} = $m1->{1}{1}*$m2->{2}{1} + $m1->{2}{1}*$m2->{2}{2} + $m1->{3}{1}*$m2->{2}{3};
	$self->{2}{2} = $m1->{1}{2}*$m2->{2}{1} + $m1->{2}{2}*$m2->{2}{2} + $m1->{3}{2}*$m2->{2}{3};
	$self->{2}{3} = $m1->{1}{3}*$m2->{2}{1} + $m1->{2}{3}*$m2->{2}{2} + $m1->{3}{3}*$m2->{2}{3};
	$self->{2}{4} = 0;

	$self->{3}{1} = $m1->{1}{1}*$m2->{3}{1} + $m1->{2}{1}*$m2->{3}{2} + $m1->{3}{1}*$m2->{3}{3};
	$self->{3}{2} = $m1->{1}{2}*$m2->{3}{1} + $m1->{2}{2}*$m2->{3}{2} + $m1->{3}{2}*$m2->{3}{3};
	$self->{3}{3} = $m1->{1}{3}*$m2->{3}{1} + $m1->{2}{3}*$m2->{3}{2} + $m1->{3}{3}*$m2->{3}{3};
	$self->{3}{4} = 0;

	$self->{4}{1} = $m1->{1}{1}*$m2->{4}{1} + $m1->{2}{1}*$m2->{4}{2} + $m1->{3}{1}*$m2->{4}{3} + $m1->{4}{1};
	$self->{4}{2} = $m1->{1}{2}*$m2->{4}{1} + $m1->{2}{2}*$m2->{4}{2} + $m1->{3}{2}*$m2->{4}{3} + $m1->{4}{2};
	$self->{4}{3} = $m1->{1}{3}*$m2->{4}{1} + $m1->{2}{3}*$m2->{4}{2} + $m1->{3}{3}*$m2->{4}{3} + $m1->{4}{3};
	$self->{4}{4} = 1;	
}
####################################################
package CTime;
use strict;
use stkutils::debug qw(fail);
sub new {
	my $self = shift;
	$self->{year} = 0;
	$self->{month} = 0;
	$self->{day} = 0;
	$self->{hour} = 0;
	$self->{min} = 0;
	$self->{sec} = 0;
	$self->{ms} = 0;
}
sub set {
	my $self = shift;
	fail('undefined arguments') if $#_ < 0;
	$self->{year} = $_[0] + 2000;
	$self->{month} = $_[1] if $#_ > 0;
	$self->{day} = $_[2] if $#_ > 1;
	$self->{hour} = $_[3] if $#_ > 2;
	$self->{min} = $_[4] if $#_ > 3;
	$self->{sec} = $_[5] if $#_ > 4;
	$self->{ms} = $_[6] if $#_ == 6;
}
sub get_all {return $_[0]->{year}, $_[0]->{month}, $_[0]->{day}, $_[0]->{hour}, $_[0]->{min}, $_[0]->{sec}, $_[0]->{ms}}
####################################################
package XRTime;
use strict;
use stkutils::debug qw(fail);
sub new {
	my $self = shift;
	$self->{year} = 0;
	$self->{month} = 0;
	$self->{day} = 0;
	$self->{hour} = 0;
	$self->{min} = 0;
	$self->{sec} = 0;
	$self->{ms} = 0;
}
use overload ('<=>' => \&threeway_compare); 
sub threeway_compare { 
	my ($t1, $t2) = @_; 
	return $t1->{year} <=> $t2->{year} if $t1->{year} != $t2->{year};
	return $t1->{month} <=> $t2->{month} if $t1->{month} != $t2->{month};
	return $t1->{day} <=> $t2->{day} if $t1->{day} != $t2->{day};
	return $t1->{hour} <=> $t2->{hour} if $t1->{hour} != $t2->{hour};
	return $t1->{min} <=> $t2->{min} if $t1->{min} != $t2->{min};
	return $t1->{sec} <=> $t2->{sec} if $t1->{sec} != $t2->{sec};
	return $t1->{ms} <=> $t2->{ms} if $t1->{ms} != $t2->{ms};
} 
sub set {
	my $self = shift;
	fail('undefined arguments') if $#_ < 0;
	$self->{year} = $_[0] if defined $_[0];
	$self->{month} = $_[1] if defined $_[1];
	$self->{day} = $_[2] if defined $_[2];
	$self->{hour} = $_[3] if defined $_[3];
	$self->{min} = $_[4] if defined $_[4];
	$self->{sec} = $_[5] if defined $_[5];
	$self->{ms} = $_[6] if defined $_[6];
}
sub setHMSms {
	my $self = shift;
	fail('undefined arguments') if $#_ < 0;
	my $low = $_[0];
	my $t = Math::BigInt->new($_[1]);
	$t->blsft(32);
	$t->badd($low);
	my $full;
	my $dm = 0;
	#msec
	($full, $self->{ms}) = $t->bdiv(1000);
	#sec
	($full, $self->{sec}) = $t->bdiv(60);
	#minutes
	($full, $self->{min}) = $t->bdiv(60);
	#hours
	($full, $self->{hour}) = $t->bdiv(24);
	#years
	($self->{year}, $full) = $t->bdiv(365);
	SWITCH: {
		$full > 0 && do {$self->{month} += 1; $dm += 0};
		$full > 31 && do {$self->{month} += 1; $dm += 31};
		$full > 59 && do {$self->{month} += 1; $dm += 28};
		$full > 90 && do {$self->{month} += 1; $dm += 31};
		$full > 120 && do {$self->{month} += 1; $dm += 30};
		$full > 151 && do {$self->{month} += 1; $dm += 31};
		$full > 181 && do {$self->{month} += 1; $dm += 30};
		$full > 212 && do {$self->{month} += 1; $dm += 31};
		$full > 243 && do {$self->{month} += 1; $dm += 31};
		$full > 273 && do {$self->{month} += 1; $dm += 30};
		$full > 304 && do {$self->{month} += 1; $dm += 31};
		$full > 334 && do {$self->{month} += 1; $dm += 30};
	}
	$self->{day} = $full->bsub($dm);
}
sub get_raw {
	my $self = shift;
	my $t = Math::BigInt->new($self->{year} * 365);
	my $days = 0;
	SWITCH: {
		$self->{month} > 0 && do {$days += 0};
		$self->{month} > 1 && do {$days += 31};
		$self->{month} > 2 && do {$days += 28};
		$self->{month} > 3 && do {$days += 31};
		$self->{month} > 4 && do {$days += 30};
		$self->{month} > 5 && do {$days += 31};
		$self->{month} > 6 && do {$days += 30};
		$self->{month} > 7 && do {$days += 31};
		$self->{month} > 8 && do {$days += 31};
		$self->{month} > 9 && do {$days += 30};
		$self->{month} > 10 && do {$days += 31};
		$self->{month} > 11 && do {$days += 30};
	}	
	$days += $self->{day};
	$t->badd($days);
	$t->bmuladd(24, $self->{hour});
	$t->bmuladd(60, $self->{min});
	$t->bmuladd(60, $self->{sec});
	$t->bmuladd(1000, $self->{ms});
	my $ct = $t->copy();
	$ct->brsft(32);
	my $hi = $ct->copy();
	my $low = $t->bsub($ct->blsft(32));
	return $low, $hi;
}
sub get_all {return $_[0]->{year}, $_[0]->{month}, $_[0]->{day}, $_[0]->{hour}, $_[0]->{min}, $_[0]->{sec}, $_[0]->{ms}}
####################################################
package waveform;
use strict;
sub new {
	my ($self) = @_;
	$self->{function_type} = 0;
	$self->{args} = ();
}
sub set {
	my $self = shift;
	$self->{function_type} = shift;
	@{$self->{args}} = @_;
}
sub get {return $_[0]->{function_type}, @{$_[0]->{args}};}
####################################################
1;