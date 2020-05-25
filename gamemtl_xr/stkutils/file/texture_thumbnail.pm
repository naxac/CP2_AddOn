# Module for handling thm files
# Update history:
#	20/01/2013 - initial release
##################################################
package stkutils::file::texture_thumbnail;
use strict;
use stkutils::data_packet;
use stkutils::ini_file;
use stkutils::debug qw(fail warn);

use constant THM_CHUNK_VERSION					=> 0x0810;
use constant THM_CHUNK_DATA						=> 0x0811;
use constant THM_CHUNK_TEXTUREPARAM				=> 0x0812;
use constant THM_CHUNK_TYPE						=> 0x0813;
use constant THM_CHUNK_TEXTUREPARAM_TYPE		=> 0x0814;
use constant THM_CHUNK_TEXTUREPARAM_DETAIL		=> 0x0815;
use constant THM_CHUNK_TEXTUREPARAM_MATERIAL	=> 0x0816;
use constant THM_CHUNK_TEXTUREPARAM_BUMP		=> 0x0817;
use constant THM_CHUNK_TEXTUREPARAM_NMAP		=> 0x0818;
use constant THM_CHUNK_TEXTUREPARAM_FADE		=> 0x0819;

sub new {
	my $class = shift;
	my $self = {};
	$self->{version} = 0x12;
	$self->{type} = $_[0];
	bless $self, $class;
	return $self;
}
sub set_bump_name {$_[0]->{bump_name} = $_[1]}
sub set_material {$_[0]->{material} = $_[1]}
sub set_detail_name {$_[0]->{detail_name} = $_[1]}
sub set_detail_scale {$_[0]->{detail_scale} = $_[1]}
sub read {
	my $self = shift;
	my ($CDH) = @_;
	while (1) {
		my ($index, $size) = $CDH->r_chunk_open();
		defined $index or last;
		my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
		SWITCH: {
			$index == THM_CHUNK_VERSION && do { $self->read_version($packet);};
			$index == THM_CHUNK_DATA && do { $self->read_data($packet);};
			$index == THM_CHUNK_TEXTUREPARAM && do { $self->read_textureparam($packet);};
			$index == THM_CHUNK_TYPE && do { $self->read_type($packet);};
			$index == THM_CHUNK_TEXTUREPARAM_TYPE && do { $self->read_textureparam_type($packet);};
			$index == THM_CHUNK_TEXTUREPARAM_DETAIL && do { $self->read_textureparam_detail($packet);};
			$index == THM_CHUNK_TEXTUREPARAM_MATERIAL && do { $self->read_textureparam_material($packet);};
			$index == THM_CHUNK_TEXTUREPARAM_BUMP && do { $self->read_textureparam_bump($packet);};
			$index == THM_CHUNK_TEXTUREPARAM_NMAP && do { $self->read_textureparam_nmap($packet);};
			$index == THM_CHUNK_TEXTUREPARAM_FADE && do { $self->read_textureparam_fade($packet);};
		}
		$CDH->r_chunk_close();
	}
}
sub read_version {
	my $self = shift;
	my $packet = $_[0];
	($self->{version}) = $packet->unpack('v');
	fail("unknown version ".$self->{version}) unless $self->{version} == 0x12;
}
sub read_data {
	my $self = shift;
	my $packet = $_[0];
	$self->{data} = $packet->data();
}
sub read_textureparam {
	my $self = shift;
	my $packet = $_[0];
	($self->{fmt},
	$self->{flags},
	$self->{border_color},
	$self->{fade_color},
	$self->{fade_amount},
	$self->{mip_filter},
	$self->{width},
	$self->{height}) = $packet->unpack('VVVVVVVV');
	fail('there some data in packet left: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_type {
	my $self = shift;
	my $packet = $_[0];
	($self->{type}) = $packet->unpack('V');
	fail('there some data in packet left: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_textureparam_type {
	my $self = shift;
	my $packet = $_[0];
	($self->{texture_type}) = $packet->unpack('V');
	fail('there some data in packet left: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_textureparam_detail {
	my $self = shift;
	my $packet = $_[0];
	($self->{detail_name},
	$self->{detail_scale}) = $packet->unpack('Z*f');
	fail('there some data in packet left: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_textureparam_material {
	my $self = shift;
	my $packet = $_[0];
	($self->{material},
	$self->{material_weight}) = $packet->unpack('Vf');
	fail('there some data in packet left: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_textureparam_bump {
	my $self = shift;
	my $packet = $_[0];
	($self->{bump_virtual_height},
	$self->{bump_mode},
	$self->{bump_name}) = $packet->unpack('fVZ*');
	fail('there some data in packet left: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_textureparam_nmap {
	my $self = shift;
	my $packet = $_[0];
	($self->{ext_normal_map_name}) = $packet->unpack('Z*');
	fail('there some data in packet left: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_textureparam_fade {
	my $self = shift;
	my $packet = $_[0];
	($self->{fade_delay}) = $packet->unpack('C');
	fail('there some data in packet left: '.$packet->resid()) unless $packet->resid() == 0;
}
sub get_data_from_texture {
	my $self = shift;
	my $data = substr(${$_[0]}, 0, 128);
	my $dwMagic = unpack('V', substr($data, 0, 4));
	fail("this is not dds") unless $dwMagic == 542327876;
	$self->{fmt} = unpack('V', substr($data, 80, 4));
	$self->{width} = unpack('V', substr($data, 12, 4));
	$self->{height} = unpack('V', substr($data, 8, 4));
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
#######################################################################
1;