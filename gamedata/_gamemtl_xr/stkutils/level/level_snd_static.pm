# Module for handling level.snd_static stalker files
# Update history:
#	10/11/2013 - fixed handling of old build files
#	27/08/2012 - initial release
##################################################
package stkutils::level::level_snd_static;
use strict;
use stkutils::data_packet;
use stkutils::ini_file;
use stkutils::debug qw(fail);
use constant FL_OLD => 0x1;
sub new {
	my $class = shift;
	my $self = {};
	$self->{flag} = 0;
	$self->{config} = {};
	bless $self, $class;
	return $self;
}
sub set_flag {$_[0]->{flag} |= $_[1]}
sub get_flag {return $_[0]->{flag}}
sub get_src {return $_[0]->{config}->{src}}
sub mode {return $_[0]->{config}->{mode}}
sub old {
	if ($_[0]->{flag} & FL_OLD == FL_OLD) {
		return 1;
	}
	return 0;	
}
sub read {
	my $self = shift;
	my ($CDH) = @_;
	my $expected_index = 0;
	while (1) {
		my ($index, $size) = $CDH->r_chunk_open();
		defined $index or last;
		fail('chunk '.$index.' have unproper index') unless $expected_index == $index;
		
		if (!$self->old()) {
			my ($in_index, $in_size) = $CDH->r_chunk_open();
			fail('cant find chunk 0') if $in_index != 0;
		}
		
		my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
		my $snd_static = snd_static->new();
		$snd_static->{flag} = $self->get_flag();
		$snd_static->read($packet);
		fail('there is some data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
		push @{$self->{snd_statics}}, $snd_static;
		$expected_index++;
		
		if (!$self->old()) {
			$CDH->r_chunk_close();
		}
		
		$CDH->r_chunk_close();
	}
}
sub write {
	my $self = shift;
	my ($CDH) = @_;
	my $index = 0;
	foreach my $snd_static (@{$self->{snd_statics}}) {
		my $packet = stkutils::data_packet->new();
		$snd_static->write($packet);
		$CDH->w_chunk_open($index);
		if (!$self->old()) {
			$CDH->w_chunk(0, $packet->data());
		} else {
			$CDH->w_chunk_data($packet->data());
		}
		$CDH->w_chunk_close();
		$index++;
	}
}
sub my_import {
	my $self = shift;
	my $IFH = stkutils::ini_file->new($_[0], 'r') or die;
	foreach my $section (@{$IFH->{sections_list}}) {
		my $snd_static = snd_static->new();
		$snd_static->{flag} = $self->get_flag();
		$snd_static->import($IFH, $section);
		push @{$self->{snd_statics}}, $snd_static;
	}
	$IFH->close()
}
sub export {
	my $self = shift;
	my $IFH = stkutils::ini_file->new($_[0], 'w') or die;
	my $RFH = $IFH->{fh};
	my $index = 0;
	foreach my $snd_static (@{$self->{snd_statics}}) {
		print $RFH "[$index]\n";
		$snd_static->export($IFH, "$index");
		print $RFH "\n";
		$index++;
	}
	$IFH->close()
}
#######################################################################
package snd_static;
use strict;
use constant FL_OLD => 0x1;
use constant first_properties_info => (
	{ name => 'sound_name',		type => 'sz' },
	{ name => 'position',		type => 'f32v3' },
	{ name => 'volume',		type => 'f32' },
	{ name => 'frequency',		type => 'f32' },
);
use constant second_properties_info => (
	{ name => 'active_time',		type => 'u32v2' },
	{ name => 'play_time',		type => 'u32v2' },
	{ name => 'pause_time',	type => 'u32v2' },
);
use constant third_properties_info => (
	{ name => 'min_dist',		type => 'f32' },
	{ name => 'max_dist',		type => 'f32' },
);
sub new {
	my $class = shift;
	my $self = {};
	$self->{type} = 0;
	bless $self, $class;
	return $self;
}
sub read {
	$_[1]->unpack_properties($_[0], first_properties_info);
	if ($_[0]->old()) {
		$_[1]->unpack_properties($_[0], third_properties_info);
	} else {
		$_[1]->unpack_properties($_[0], second_properties_info);
	}
}
sub write {
	$_[1]->pack_properties($_[0], first_properties_info);
	if ($_[0]->old()) {
		$_[1]->pack_properties($_[0], third_properties_info);
	} else {
		$_[1]->pack_properties($_[0], second_properties_info);
	}
}
sub import {
	$_[1]->import_properties($_[2], $_[0], first_properties_info);
	if ($_[0]->old()) {
		$_[1]->import_properties($_[2], $_[0], third_properties_info);
	} else {
		$_[1]->import_properties($_[2], $_[0], second_properties_info);
	}
}
sub export {
	$_[1]->export_properties(undef, $_[0], first_properties_info);
	if ($_[0]->old()) {
		$_[1]->export_properties(undef, $_[0], third_properties_info);
	} else {
		$_[1]->export_properties(undef, $_[0], second_properties_info);
	}
}
sub old {
	if ($_[0]->{flag} & FL_OLD == FL_OLD) {
		return 1;
	}
	return 0;	
}
#######################################################################
1;