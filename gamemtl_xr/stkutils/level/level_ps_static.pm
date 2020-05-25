# Module for handling level.ps_static stalker files
# Update history:
#	17/01/2013 - initial release
##################################################
package stkutils::level::level_ps_static;
use strict;
use stkutils::data_packet;
use stkutils::ini_file;
use stkutils::debug qw(fail warn);

sub new {
	my $class = shift;
	my $self = {};
	$self->{flag} = 0;
	$self->{config} = {};
	bless $self, $class;
	return $self;
}
sub read {
	my $self = shift;
	my ($CDH) = @_;
	my $expected_index = 0;
	if ($self->{flag} == 1) {
		my ($index, $size) = $CDH->r_chunk_open();
#		warn('load switch is off') unless $index == 1;
		$CDH->r_chunk_close();
		$expected_index = 1;
	}
	while (1) {
		my ($index, $size) = $CDH->r_chunk_open();
		defined $index or last;
		fail('chunk '.$index.' have unproper index') unless $expected_index == $index;
		my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
		my $ps_static = ps_static->new();
		$ps_static->{flag} = $self->{flag};
		$ps_static->read($packet);
		fail('there is some data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
		push @{$self->{ps_statics}}, $ps_static;
		$expected_index++;
		$CDH->r_chunk_close();
	}
}
sub write {
	my $self = shift;
	my ($CDH) = @_;
	my $index = 0;
	if ($self->{flag} == 1) {
		$CDH->w_chunk($index++, pack('V', 1));
	}
	foreach my $ps_static (@{$self->{ps_statics}}) {
		my $packet = stkutils::data_packet->new();
		$ps_static->write($packet);
		$CDH->w_chunk($index++, $packet->data());
	}
}
sub my_import {
	my $self = shift;
	my $IFH = stkutils::ini_file->new($_[0], 'r') or die;
	foreach my $section (@{$IFH->{sections_list}}) {
		my $ps_static = ps_static->new();
		$ps_static->{flag} = $self->{flag};
		$ps_static->import($IFH, $section);
		push @{$self->{ps_statics}}, $ps_static;
	}
	$IFH->close()
}
sub export {
	my $self = shift;
	my $IFH = stkutils::ini_file->new($_[0], 'w') or die;
	my $RFH = $IFH->{fh};
	my $index = 0;
	foreach my $ps_static (@{$self->{ps_statics}}) {
		print $RFH "[$index]\n";
		$ps_static->export($IFH, "$index");
		print $RFH "\n";
		$index++;
	}
	$IFH->close()
}
#######################################################################
package ps_static;
use strict;
use constant properties_info => (
	{ name => 'particle_name',		type => 'sz' },
	{ name => 'matrix_1',		type => 'f32v4' },
	{ name => 'matrix_2',		type => 'f32v4' },
	{ name => 'matrix_3',		type => 'f32v4' },
	{ name => 'matrix_4',		type => 'f32v4' },
);
use constant cs_properties_info => (
	{ name => 'load_switch',		type => 'u16' },
);
sub new {
	my $class = shift;
	my $self = {};
	$self->{flag} = 0;
	bless $self, $class;
	return $self;
}
sub read {
	if ($_[0]->{flag} == 1) {
		$_[1]->unpack_properties($_[0], cs_properties_info);
	}
	$_[1]->unpack_properties($_[0], properties_info);
}
sub write {
	if ($_[0]->{flag} == 1) {
		$_[1]->pack_properties($_[0], cs_properties_info);
	}
	$_[1]->pack_properties($_[0], properties_info);
}
sub import {
	if ($_[0]->{flag} == 1) {
		$_[1]->import_properties($_[2], $_[0], cs_properties_info);
	}
	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub export {
	if ($_[0]->{flag} == 1) {
		$_[1]->export_properties(undef, $_[0], cs_properties_info);
	}
	$_[1]->export_properties(undef, $_[0], properties_info);
}
#######################################################################
1;