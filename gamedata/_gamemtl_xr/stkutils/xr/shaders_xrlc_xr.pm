# S.T.A.L.K.E.R. shaders_xrlc.xr handling module
# Update history: 
#	28/08/2012 - initial release
##############################################
package stkutils::xr::shaders_xrlc_xr;
use strict;
use stkutils::debug qw(fail);
use stkutils::data_packet;

use constant FL_CSF_COLLISION => 0x1;
use constant FL_CSF_RENDERING => 0x2;
use constant FL_CSF_OPTIMIZE_UV => 0x4;
use constant FL_CSF_VERTEX_LIGHT => 0x8;
use constant FL_CSF_CAST_SHADOW => 0x10;
use constant FL_CSF_UNKNOWN_1 => 0x20;
use constant FL_CSF_UNKNOWN_2 => 0x40;

sub new {
	my $class = shift;
	my $self = {};
	$self->{data} = '';
	$self->{data} = $_[0] if defined $_[0];
	bless($self, $class);
	return $self;
}
sub read {
	my $self = shift;

	my $packet = stkutils::data_packet->new($self->{data});
	my $shCount = $packet->length()/0x90;
	fail('bad file') unless $packet->length()%0x90 == 0;
	for (my $i = 0; $i < $shCount; $i++) {
		my $shader = {};
		my $pos = $packet->pos();
		($shader->{name}) = $packet->unpack('Z*');
		$packet->pos($pos + 0x80);	
		($shader->{flags},
		$shader->{translucency},
		$shader->{ambient},
		$shader->{lm_density}) =  $packet->unpack('Vfff');
		push @{$self->{shaders}}, $shader;
	}
	fail('there is some data left in packet:'.$packet->resid()) unless $packet->resid() == 0;
}
sub write {
	my $self = shift;
	
	my $packet = stkutils::data_packet->new();
	foreach my $object (@{$self->{shaders}}) {
		$packet->pack('Z*', $object->{name});
		my $zero_count = 0x80 - length($object->{name}) - 1;
		for (my $i = 0; $i < $zero_count; $i++) {
			$packet->pack('C',0);
		}
		$packet->pack('Vfff', $object->{flags}, $object->{translucency}, $object->{ambient}, $object->{lm_density});
	}
	$self->{data} = \$packet->data();
}
sub export {
	my $self = shift;
	my ($ini) = @_;
	
	print $ini "[shaders_xrlc]\n";
	print $ini "count = ".($#{$self->{shaders}} + 1)."\n";
	my $i = 0;
	foreach my $shader (@{$self->{shaders}}) {
		print $ini "[$i]\n";
		print $ini "name = $shader->{name}\n";
		print $ini "flags = ";
		my $bFlags = $shader->{flags};
		if ($bFlags & FL_CSF_COLLISION == FL_CSF_COLLISION) {print $ini "CSF_COLLISION,"}
		if ($bFlags & FL_CSF_RENDERING == FL_CSF_RENDERING) {print $ini "CSF_RENDERING,"}
		if ($bFlags & FL_CSF_OPTIMIZE_UV == FL_CSF_OPTIMIZE_UV) {print $ini "CSF_OPTIMIZE_UV,"}
		if ($bFlags & FL_CSF_VERTEX_LIGHT == FL_CSF_VERTEX_LIGHT) {print $ini "CSF_VERTEX_LIGHT,"}
		if ($bFlags & FL_CSF_CAST_SHADOW == FL_CSF_CAST_SHADOW) {print $ini "CSF_CAST_SHADOW,"}
		if ($bFlags & FL_CSF_UNKNOWN_1 == FL_CSF_UNKNOWN_1) {print $ini "CSF_UNKNOWN_1,"}
		if ($bFlags & FL_CSF_UNKNOWN_2 == FL_CSF_UNKNOWN_2) {print $ini "CSF_UNKNOWN_2,"}
		if (($bFlags & 0x80) != 0) {print "$shader->{name}: SOME ADDITIONAL FLAGS EXISTS!\n"}
		printf $ini "\n";
		printf $ini "translucency = %.5g\n", $shader->{translucency};
		printf $ini "ambient = %.5g\n", $shader->{ambient};
		printf $ini "lm_density = %.5g\n", $shader->{lm_density};
		$i++;
	}
}
sub my_import {
	my $self = shift;
	my ($ini) = @_;
	
	my ($count) = $ini->value('shaders_xrlc', 'count');
	for (my $i = 0; $i < $count; $i++) {
		my $shader = {};
		my $conv_flags = 0;
		my @raw_flags = split /,\s*/, $ini->value("$i", 'flags');
		foreach my $flag (@raw_flags) {
			if ($flag eq 'CSF_COLLISION') {$conv_flags &= FL_CSF_COLLISION;}
			if ($flag eq 'CSF_RENDERING') {$conv_flags &= FL_CSF_RENDERING;}
			if ($flag eq 'CSF_OPTIMIZE_UV') {$conv_flags &= FL_CSF_OPTIMIZE_UV;}
			if ($flag eq 'CSF_VERTEX_LIGHT') {$conv_flags &= FL_CSF_VERTEX_LIGHT;}
			if ($flag eq 'CSF_CAST_SHADOW') {$conv_flags &= FL_CSF_CAST_SHADOW;}
			if ($flag eq 'CSF_UNKNOWN_1') {$conv_flags &= FL_CSF_UNKNOWN_1;}
			if ($flag eq 'CSF_UNKNOWN_2') {$conv_flags &= FL_CSF_UNKNOWN_2;}
		}
		$shader->{dummy} = $conv_flags;
		$shader->{name} = $ini->value("$i", 'name');
		$shader->{translucency} = $ini->value("$i", 'translucency');
		$shader->{ambient} = $ini->value("$i", 'ambient');
		$shader->{lm_density} = $ini->value("$i", 'lm_density');
		push @{$self->{shaders}}, $shader;
	}
}
#################################################################################
1;