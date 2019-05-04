# Module for handling level stalker files
# Update history:
#	27/08/2012 - fix code for new fail() syntax
##################################################
package stkutils::level::level;
use strict;
use Cwd;
use stkutils::chunked;
use stkutils::level::level_cform;
use stkutils::debug qw(fail);
use vars qw(@ISA @EXPORT_OK);
require Exporter;

@ISA		= qw(Exporter);
@EXPORT_OK	= qw(import_data export_data);
sub new {
	my $class = shift;
	my $self = {};
	$self->{data} = '';
	$self->{data} = $_[0] if defined $_[0];
	bless($self, $class);
	return $self;
}
sub version {
	$_[0]->{fsl_header}->{xrlc_version} = $_[1] if $#_ == 1;
	return $_[0]->{fsl_header}->{xrlc_version};
}
sub init_data_fields {
	my $self = shift;
	$self->{fsl_header}->{xrlc_version} = $_[0];
	$self->{fsl_portals} = fsl_portals->new($_[0]);
	$self->{fsl_light_dynamic} = fsl_light_dynamic->new($_[0]);
	$self->{fsl_glows} = fsl_glows->new($_[0]);
	$self->{fsl_visuals} = fsl_visuals->new($_[0]);
	$self->{fsl_vertex_buffer} = fsl_vertex_buffer->new($_[0]) if (-e 'FSL_VB.bin' || -e 'FSL_VB.ltx');
	$self->{fsl_shaders} = fsl_shaders->new($_[0]);
	$self->{fsl_sectors} = fsl_sectors->new($_[0]);
	$self->{compressed} = compressed->new($_[0]);
	if ($_[0] > 8) {
		$self->{fsl_index_buffer} = fsl_index_buffer->new($_[0]) if (-e 'FSL_IB.bin' || -e 'FSL_IB.ltx');
	}
	if ($_[0] < 8) {
		$self->{fsl_light_key_frames} = fsl_light_key_frames->new($_[0]);
		$self->{fsl_textures} = fsl_textures->new($_[0]);
	}
	if ($_[0] == 9) {
		$self->{fsl_shader_constant} = fsl_shader_constant->new($_[0]);
	}	
	if ($_[0] > 11) {
		$self->{fsl_swis} = fsl_swis->new($_[0]) if (-e 'FSL_SWIS.bin' || -e 'FSL_SWIS .ltx');
	} else {
		$self->{fsl_cform} = stkutils::level::level_cform->new($_[0]) if (-e 'FSL_CFORM.bin' || -e 'FSL_CFORM.ltx');
	}
}
sub read {
	my $self = shift;
	my ($fh) = @_;
	
	if ($#_ == -1) { 
		$fh = stkutils::chunked->new($self->{data}, 'data') or fail("$!\n");
	}
	while (1) {
		my ($index, $size) = $fh->r_chunk_open();
		defined $index or last;
		last unless $index != 0;
		my $data = $fh->r_chunk_data();
		SWITCH: {
			$index == 0x1 && do {
				$self->{fsl_header} = fsl_header->new($data); 
				$self->{fsl_header}->decompile();
				$self->{compressed} = compressed->new($self->{fsl_header}->{xrlc_version});
				last SWITCH;};
			(chunks::get_name($index, $self->{fsl_header}->{xrlc_version}) eq 'FSL_CFORM') && do {
				$self->{fsl_cform} = stkutils::level::level_cform->new($self->{fsl_header}->{xrlc_version}, $data); 
				last SWITCH; };
			(chunks::get_name($index, $self->{fsl_header}->{xrlc_version}) eq 'FSL_PORTALS') && do {
				$self->{fsl_portals} = fsl_portals->new($self->{fsl_header}->{xrlc_version}, $data); 
				last SWITCH;};
			(chunks::get_name($index, $self->{fsl_header}->{xrlc_version}) eq 'FSL_SHADER_CONSTANT') && do {
				$self->{fsl_shader_constant} = fsl_shader_constant->new($self->{fsl_header}->{xrlc_version}, $data); 
				last SWITCH;};
			(chunks::get_name($index, $self->{fsl_header}->{xrlc_version}) eq 'FSL_LIGHT_DYNAMIC') && do {
				$self->{fsl_light_dynamic} = fsl_light_dynamic->new($self->{fsl_header}->{xrlc_version}, $data); 
				last SWITCH;};
			(chunks::get_name($index, $self->{fsl_header}->{xrlc_version}) eq 'FSL_LIGHT_KEY_FRAMES') && do {
				$self->{fsl_light_key_frames} = fsl_light_key_frames->new($self->{fsl_header}->{xrlc_version}, $data); 
				last SWITCH;};
			(chunks::get_name($index, $self->{fsl_header}->{xrlc_version}) eq 'FSL_GLOWS') && do {
				$self->{fsl_glows} = fsl_glows->new($self->{fsl_header}->{xrlc_version}, $data); 
				last SWITCH; };
			(chunks::get_name($index, $self->{fsl_header}->{xrlc_version}) eq 'FSL_VISUALS') && do {
				$self->{fsl_visuals} = fsl_visuals->new($self->{fsl_header}->{xrlc_version}, $data); 
				last SWITCH;};
			(chunks::get_name($index, $self->{fsl_header}->{xrlc_version}) eq 'FSL_VB') && do {
				$self->{fsl_vertex_buffer} = fsl_vertex_buffer->new($self->{fsl_header}->{xrlc_version}, $data); 
				last SWITCH;};
			(chunks::get_name($index, $self->{fsl_header}->{xrlc_version}) eq 'FSL_SWIS') && do {
				$self->{fsl_swis} = fsl_swis->new($self->{fsl_header}->{xrlc_version}, $data); 
				last SWITCH;};
			(chunks::get_name($index, $self->{fsl_header}->{xrlc_version}) eq 'FSL_IB') && do {
				$self->{fsl_index_buffer} = fsl_index_buffer->new($self->{fsl_header}->{xrlc_version}, $data); 
				last SWITCH;};
			(chunks::get_name($index, $self->{fsl_header}->{xrlc_version}) eq 'FSL_TEXTURES') && do {
				$self->{fsl_textures} = fsl_textures->new($self->{fsl_header}->{xrlc_version}, $data); 
				last SWITCH;};
			(chunks::get_name($index, $self->{fsl_header}->{xrlc_version}) eq 'FSL_SHADERS') && do {
				$self->{fsl_shaders} = fsl_shaders->new($self->{fsl_header}->{xrlc_version}, $data); 
				last SWITCH;};
			(chunks::get_name($index, $self->{fsl_header}->{xrlc_version}) eq 'FSL_SECTORS') && do {
				$self->{fsl_sectors} = fsl_sectors->new($self->{fsl_header}->{xrlc_version}, $data); 
				last SWITCH;};
			($index & 0x80000000) && do {
				$index -= 0x80000000; 
				$self->{compressed}->add($index, $data); 
				last SWITCH; };
			fail ("unexpected chunk $index size $size\n");
			}
		$fh->r_chunk_close();
	}	
	$fh->close() if ($#_ == -1);
}
sub copy {
	my $self = shift;
	my ($copy) = @_;
	$copy->{fsl_header} = $self->{fsl_header};
	$copy->{fsl_portals} = $self->{fsl_portals};
	$copy->{fsl_light_dynamic} = $self->{fsl_light_dynamic};
	$copy->{fsl_glows} = $self->{fsl_glows};	
	$copy->{fsl_visuals} = $self->{fsl_visuals};	
	$copy->{fsl_shaders} = $self->{fsl_shaders};	
	$copy->{fsl_sectors} = $self->{fsl_sectors};	
}	
sub write {
	my $self = shift;
	my ($fh) = @_;
	if ($#_ == -1) { 
		$fh = stkutils::chunked->new('', 'data') or fail("$!\n");
	}
	my $ver = $self->{fsl_header}->{xrlc_version};
	$self->{fsl_header}->write($fh);
	if ($ver < 10) {
		if (defined $self->{fsl_cform}->{data}) {	
			$self->{fsl_cform}->write($fh);
		} elsif (defined $self->{compressed}->{'FSL_CFORM'}) {
			$self->{compressed}->write(chunks::get_index('FSL_CFORM', $self->{fsl_header}->{xrlc_version}), $fh);
		} else {
			fail('cant find FSL_CFORM');
		}	
		$self->{fsl_portals}->write($fh);		
	} elsif ($ver == 10) {
		$self->{fsl_portals}->write($fh);
		if (defined $self->{fsl_cform}->{data}) {	
			$self->{fsl_cform}->write($fh);
		} elsif (defined $self->{compressed}->{'FSL_CFORM'}) {
			$self->{compressed}->write(chunks::get_index('FSL_CFORM', $self->{fsl_header}->{xrlc_version}), $fh);
		} else {
			fail('cant find FSL_CFORM');
		}		
	} else {
		$self->{fsl_portals}->write($fh);
	}
	if ($ver == 9) {
		$self->{fsl_shader_constant}->write($fh);	
	}
	$self->{fsl_light_dynamic}->write($fh);
	if ($ver < 8) {
		$self->{fsl_light_key_frames}->write($fh);	
	}
	$self->{fsl_glows}->write($fh);
	if (defined $self->{fsl_visuals}->{data}) {
		$self->{fsl_visuals}->write($fh);
	} elsif (defined $self->{compressed}->{'FSL_VISUALS'}) {
		$self->{compressed}->write(chunks::get_index('FSL_VISUALS', $self->{fsl_header}->{xrlc_version}), $fh);
	} else {
		fail('cant find FSL_VISUALS');
	}
	if ($ver < 13) {	
		if (defined $self->{fsl_vertex_buffer}->{data}) {
			$self->{fsl_vertex_buffer}->write($fh);	
		} elsif (chunks::get_index('FSL_VB', $self->{fsl_header}->{xrlc_version}) && defined $self->{compressed}->{'FSL_VB'}) {
			$self->{compressed}->write(chunks::get_index('FSL_VB', $self->{fsl_header}->{xrlc_version}), $fh);
		} else {
			fail('cant find FSL_VB');
		}
		if ($ver > 11) {
			if (defined $self->{fsl_swis}->{data}) {
				$self->{fsl_swis}->write($fh);
			} elsif (defined $self->{compressed}->{'FSL_SWIS'}) {
				$self->{compressed}->write('FSL_SWIS', $fh);
			}
		}
		if ($ver > 8) {
			if (defined $self->{fsl_index_buffer}->{data}) {
				$self->{fsl_index_buffer}->write($fh);
			} elsif (chunks::get_index('FSL_IB', $self->{fsl_header}->{xrlc_version}) && defined $self->{compressed}->{'FSL_IB'}) {
				$self->{compressed}->write(chunks::get_index('FSL_IB', $self->{fsl_header}->{xrlc_version}), $fh);
			} else {
				fail('cant find FSL_IB');
			}
		}
	}
	$self->{fsl_textures}->write($fh) if $ver < 8;
	$self->{fsl_shaders}->write($fh);
	if (defined $self->{fsl_sectors}->{data}) {
		$self->{fsl_sectors}->write($fh);
	} elsif (defined $self->{compressed}->{'FSL_SECTORS'}) {
		$self->{compressed}->write(chunks::get_index('FSL_SECTORS', $self->{fsl_header}->{xrlc_version}), $fh);
	} else {
		fail('cant find FSL_SECTORS');
	}
	if ($#_ == -1) {
		$self->{data} = $fh->data();
		$fh->close();
	}
}
sub my_import {
	my $self = shift;	
	$self->{fsl_header} = fsl_header->new();
	$self->{fsl_header}->import_ltx();
	$self->init_data_fields($self->{fsl_header}->{xrlc_version});
	import_data($self->{fsl_cform}) if defined $self->{fsl_cform}->{data};
	import_data($self->{fsl_portals}) if defined $self->{fsl_portals}->{data};
	import_data($self->{fsl_shader_constant}) if defined $self->{fsl_shader_constant}->{data};
	import_data($self->{fsl_light_dynamic});
	import_data($self->{fsl_light_key_frames}) if defined $self->{fsl_light_key_frames}->{data};
	import_data($self->{fsl_glows});
	import_data($self->{fsl_visuals}) if defined $self->{fsl_visuals}->{data};
	import_data($self->{fsl_vertex_buffer}) if defined $self->{fsl_vertex_buffer}->{data};
	import_data($self->{fsl_swis}) if defined $self->{fsl_swis}->{data};
	import_data($self->{fsl_index_buffer}) if defined $self->{fsl_index_buffer}->{data};
	import_data($self->{fsl_textures}) if defined $self->{fsl_textures}->{data};
	import_data($self->{fsl_shaders});
	import_data($self->{fsl_sectors}) if defined $self->{fsl_sectors}->{data};
	import_compressed($self->{compressed}) if defined $self->{compressed};
}
sub export {
	my $self = shift;
	export_data($self->{fsl_header}, 'ltx');
	export_data($self->{fsl_cform}) if defined $self->{fsl_cform}->{data};
	export_data($self->{fsl_portals}) if defined $self->{fsl_portals}->{data};
	export_data($self->{fsl_shader_constant}) if defined $self->{fsl_shader_constant}->{data};
	export_data($self->{fsl_light_dynamic});
	export_data($self->{fsl_light_key_frames}) if defined $self->{fsl_light_key_frames}->{data};
	export_data($self->{fsl_glows});
	export_data($self->{fsl_visuals}) if defined $self->{fsl_visuals}->{data};
	export_data($self->{fsl_vertex_buffer}) if defined $self->{fsl_vertex_buffer}->{data};
	export_data($self->{fsl_swis}) if defined $self->{fsl_swis}->{data};
	export_data($self->{fsl_index_buffer}) if defined $self->{fsl_index_buffer}->{data};
	export_data($self->{fsl_textures}) if defined $self->{fsl_textures}->{data};
	export_data($self->{fsl_shaders});
	export_data($self->{fsl_sectors}) if defined $self->{fsl_sectors}->{data};
	if (defined $self->{compressed}) {
		foreach my $chunk (keys %{$self->{compressed}}) {
			$self->{compressed}->export($chunk);
		}
	}
}
sub export_data {
	my ($self, $mode) = @_;
	
	my $ref = ref($self);
	if (defined $mode) {
		if ($mode eq 'bin') {
			export_bin($self);
		} elsif ($mode eq 'ltx') {
			$self->export_ltx();
		} else {
			fail('Unsupported mode. Use only bin or ltx');
		}
	} else {
		export_bin($self);
	}	
}
sub export_bin {
	my ($self) = @_;
	my $ref = ref($self);
	if ($ref =~ /(level)_(\w+)/) {
		$ref = 'FSL_'.$2;
	}
	my $fh = IO::File->new(uc($ref).'.bin', 'w');	
	binmode $fh;
	$fh->write(${$self->{data}}, length(${$self->{data}}));
	$fh->close();
}
sub import_data {
	my ($self, $mode) = @_;
	
	my $ref = ref($self);
	if (defined $mode) {
		if ($mode eq 'bin') {
			import_bin($self);
		} elsif ($mode eq 'ltx') {
			$self->import_ltx();
		} else {
			fail('Unsupported mode. Use only bin or ltx');
		}
	} else {
		if ($ref =~ /(level)_(\w+)/) {
			$ref = 'FSL_'.$2;
		}
		if (-e $ref.'.ltx') {
			$self->import_ltx();
		} elsif (-e $ref.'.bin') {
			import_bin($self);
		} else {
			fail('There is no '.ref($self).'.ltx or '.ref($self).'.bin')
		}
	}	
}
sub import_bin {
	my ($self) = @_;
	my $ref = ref($self);
	if ($ref =~ /(level)_(\w+)/) {
		$ref = 'FSL_'.$2;
	}
	my $fh = IO::File->new($ref.'.bin', 'r') or fail(ref($self).".bin: $!\n");
	binmode $fh;
	my $data = '';
	$fh->read($data, ($fh->stat())[7]);
	$fh->close();
	$self->{data} = \$data;	
}
sub import_compressed {
	my ($self) = @_;
	my @comp_list = glob "{COMPRESSED}*.{bin}";
	if ($#comp_list != -1) {
		foreach my $file (@comp_list) {
			$self->import($file);
		}
	}
}
sub new_fsl_portals {shift; return fsl_portals->new(@_);}
sub new_fsl_light_dynamic {shift; return fsl_light_dynamic->new(@_);}
sub new_fsl_glows {shift; return fsl_glows->new(@_);}
sub new_fsl_visuals {shift; return fsl_visuals->new(@_);}
sub new_fsl_vertex_buffer {shift; return fsl_vertex_buffer->new(@_);}
sub new_fsl_swis {shift; return fsl_swis->new(@_);}
sub new_fsl_index_buffer {shift; return fsl_index_buffer->new(@_);}
sub new_fsl_shaders {shift; return fsl_shaders->new(@_);}
sub new_fsl_sectors {shift; return fsl_sectors->new(@_);}
############################################################
package fsl_header;
use strict;
use stkutils::ini_file;
use stkutils::debug qw(fail);
use stkutils::data_packet;
sub new {
	my $class = shift;
	my $self = {};
	$self->{data} = ($_[0] or '');
	bless($self, $class);
	return $self;
}
sub decompile {
	my $self = shift;
	my $packet = stkutils::data_packet->new($self->{data});
	($self->{xrlc_version}, $self->{xrlc_quality}) = $packet->unpack('vv', 4);
	if ($self->{xrlc_version} < 11) {
		($self->{name}) = $packet->unpack('Z*');
	} else {
		fail('there is some data left ['.$packet->resid().'] in FSL_HEADER') unless $packet->resid() == 0;
	}	
}
sub compile {
	my $self = shift;
	my $data = '';
	if ($self->{xrlc_version} > 10) {
		$data = pack('vv', $self->{xrlc_version}, $self->{xrlc_quality});
	} else {
		my $l = length($self->{name});
		my $zc = 123 - $l;
		$data = pack('vvZ*', $self->{xrlc_version}, $self->{xrlc_quality}, $self->{name});
		for (my $i = 0; $i < $zc; $i++) {
			$data .= pack('C', 0);
		}
	}	
	$self->{data} = \$data;
}
sub write {
	my $self = shift;
	my ($fh) = @_;
	$fh->w_chunk(1, ${$self->{data}});
}
sub export_ltx {
	my $self = shift;

	my $fh = IO::File->new('FSL_HEADER.ltx', 'w') or fail("FSL_HEADER.ltx: $!\n");	
	print $fh "[header]\n";
	print $fh "xrLC version = $self->{xrlc_version}\n";
	print $fh "xrLC quality = $self->{xrlc_quality}\n";
	print $fh "name = $self->{name}\n" if $self->{xrlc_version} < 11;
	$fh->close();
}
sub import_ltx {
	my $self = shift;
	my $fh = stkutils::ini_file->new('FSL_HEADER.ltx', 'r') or fail("FSL_HEADER.ltx: $!\n");
	$self->{xrlc_version} = $fh->value('header', 'xrLC version');
	$self->{xrlc_quality} = $fh->value('header', 'xrLC quality');
	$self->{name} = $fh->value('header', 'name') if $self->{xrlc_version} < 11;
	$fh->close();
}
#########################################################
package fsl_portals;
use strict;
use stkutils::ini_file;
use stkutils::debug qw(fail);
use stkutils::data_packet;
sub new {
	my $class = shift;
	my $self = {};
	$self->{version} = $_[0];
	$self->{data} = ($_[1] or '');
	bless($self, $class);
	return $self;
}
sub decompile {
	my $self = shift;
	my $mode = $_[0];
	my $packet = stkutils::data_packet->new($self->{data});
	return unless $packet->resid() != 0;
	$self->{portal_count} = $packet->resid() / 0x50;
	if ($mode && ($mode eq 'full')) {
		for (my $i = 0; $i < $self->{portal_count}; $i++) {
			my $portal = {};
			($portal->{sector_front}, $portal->{sector_back}) = $packet->unpack('vv', 4);
			if ($self->{version} >= 8) {
				for (my $j = 0; $j < 6; $j++) {
					my @point  = $packet->unpack('f3', 12);
					push @{$portal->{vertices}}, \@point;
				}
				($portal->{count}) = $packet->unpack('V', 4);
			} else {
				($portal->{count}) = $packet->unpack('V', 4);
				for (my $j = 0; $j < 6; $j++) {
					my @point  = $packet->unpack('f3', 12);
					push @{$portal->{vertices}}, \@point;
				}
			}
			push @{$self->{portals}}, $portal;
		}
		fail('there is some data left in packet ['.$packet->resid().']') unless $packet->resid() == 0;
	}
}
sub compile {
	my $self = shift;
	my $data = '';
	if ($self->{version} >= 8) {
		foreach my $portal (@{$self->{portals}}) {
			$data .= pack('vv', $portal->{sector_front}, $portal->{sector_back});
			foreach my $vertex (@{$portal->{vertices}}) {
				$data .= pack('f3', @$vertex);
			}
			$data .= pack('V', $portal->{count});
		}
	} else {
		foreach my $portal (@{$self->{portals}}) {
			$data .= pack('vv', $portal->{sector_front}, $portal->{sector_back});
			$data .= pack('V', $portal->{count});
			foreach my $vertex (@{$portal->{vertices}}) {
				$data .= pack('f3', @$vertex);
			}
		}
	}
	$self->{data} = \$data;
}
sub write {
	my $self = shift;
	my ($fh) = @_;
	my $index = chunks::get_index('FSL_PORTALS', $self->{version});
	$fh->w_chunk($index, ${$self->{data}});	
}
sub export_ltx {
	my $self = shift;

	my $fh = IO::File->new('FSL_PORTALS.ltx', 'w') or fail("FSL_PORTALS.ltx: $!\n");
	my $i = 0;
	foreach my $portal (@{$self->{portals}}) {
		print $fh "[$i]\n";
		print $fh "sector_front = $portal->{sector_front}\n";
		print $fh "sector_back = $portal->{sector_back}\n";
		printf $fh "vertex0 = %f,%f,%f\n", @{$portal->{vertices}}[0..2];
		printf $fh "vertex1 = %f,%f,%f\n", @{$portal->{vertices}}[3..5];
		printf $fh "vertex2 = %f,%f,%f\n", @{$portal->{vertices}}[6..8];
		printf $fh "vertex3 = %f,%f,%f\n", @{$portal->{vertices}}[9..11];
		printf $fh "vertex4 = %f,%f,%f\n", @{$portal->{vertices}}[12..14];
		printf $fh "vertex5 = %f,%f,%f\n", @{$portal->{vertices}}[15..17];
		print $fh "count = $portal->{count}\n\n";
		$i++;
	}
	$fh->close();
}
sub import_ltx {
	my $self = shift;

	my $fh = stkutils::ini_file->new('FSL_PORTALS.ltx', 'r') or fail("FSL_PORTALS.ltx: $!\n");	
	my $len = $#{$fh->{sections_list}} + 1;
	for (my $i = 0; $i < $len; $i++) {
		my $portal = {};
		$portal->{sector_front} = $fh->value($i, 'sector_front');
		$portal->{sector_back} = $fh->value($i, 'sector_back');
		$portal->{count} = $fh->value($i, 'count');
		@{$portal->{vertices}}[0..2] = split /,\s*/, $fh->value($i, 'vertex0');
		@{$portal->{vertices}}[3..5] = split /,\s*/, $fh->value($i, 'vertex1');
		@{$portal->{vertices}}[6..8] = split /,\s*/, $fh->value($i, 'vertex2');
		@{$portal->{vertices}}[9..11] = split /,\s*/, $fh->value($i, 'vertex3');
		@{$portal->{vertices}}[12..14] = split /,\s*/, $fh->value($i, 'vertex4');
		@{$portal->{vertices}}[15..17] = split /,\s*/, $fh->value($i, 'vertex5');
		push @{$self->{portals}}, $portal;
	}
	$fh->close();
}
#########################################################
package fsl_shader_constant;
use strict;
use stkutils::debug qw(fail);
use stkutils::ini_file;
use stkutils::data_packet;
sub new {
	my $class = shift;
	my $self = {};
	$self->{version} = $_[0];
	$self->{data} = ($_[1] or '');
	bless($self, $class);
	return $self;
}
sub decompile {
	my $self = shift;
	my $packet = stkutils::data_packet->new($self->{data});
	print "decompiling of FSL_SHADER_CONSTANT not implemented yet\n";
}
sub compile {
	my $self = shift;
	my $data = '';
	print "compiling of FSL_SHADER_CONSTANT not implemented yet\n";
	$self->{data} = \$data;
}
sub write {
	my $self = shift;
	my ($fh) = @_;
	my $index = chunks::get_index('FSL_SHADER_CONSTANT', $self->{version});
	$fh->w_chunk($index, ${$self->{data}});	
}
sub export_ltx {
	my $self = shift;

	my $fh = IO::File->new('FSL_SHADER_CONSTANT.ltx', 'w') or fail("FSL_SHADER_CONSTANT.ltx: $!\n");
	print "exporting decompiled data of FSL_SHADER_CONSTANT not implemented yet\n";
	$fh->close();
}
sub import_ltx {
	my $self = shift;
	
	my $fh = stkutils::ini_file->new('FSL_SHADER_CONSTANT.ltx', 'r') or fail("FSL_SHADER_CONSTANT.ltx: $!\n");
	print "importing decompiled data of FSL_SHADER_CONSTANT not implemented yet\n";
	$fh->close();
}
#########################################################
package fsl_light_dynamic;
use strict;
use stkutils::ini_file;
use stkutils::data_packet;
use stkutils::debug qw(fail);
use constant lt_names => {
	1	=> 'point',
	2	=> 'spot',
	3	=> 'directional',
};
use constant reverse_lt_names => {
	'point'	=> 1,
	'spot'	=> 2,
	'directional'	=> 3,
};
sub new {
	my $class = shift;
	my $self = {};
	$self->{version} = $_[0];
	$self->{data} = ($_[1] or '');
	bless($self, $class);
	return $self;
}
sub decompile {
	my $self = shift;
	my $packet = stkutils::data_packet->new($self->{data});
	if ($self->{version} > 8) {
		$self->{count} = $packet->resid() / 0x6c;
		fail('wrong size of FSL_LIGHT_DYNAMIC') unless $packet->resid() % 0x6c == 0;
		for (my $i = 0; $i < $self->{count}; $i++) {
			my $light = {};
			($light->{controller_id},
			$light->{type}) = $packet->unpack('VV', 8);
			@{$light->{diffuse}} = $packet->unpack('f4', 16);
			@{$light->{specular}} = $packet->unpack('f4', 16);
			@{$light->{ambient}} = $packet->unpack('f4', 16);
			@{$light->{position}} = $packet->unpack('f3', 12);
			@{$light->{direction}} = $packet->unpack('f3', 12);
			@{$light->{other}} = $packet->unpack('f7', 28);
			push @{$self->{lights}}, $light;
		}
	} elsif ($self->{version} > 5) {
		$self->{count} = $packet->resid() / 0xB0;
		fail('wrong size of FSL_LIGHT_DYNAMIC') unless $packet->resid() % 0xB0 == 0;
		for (my $i = 0; $i < $self->{count}; $i++) {
			my $light = {};
			($light->{type}) = $packet->unpack('V', 4);
			@{$light->{diffuse}} = $packet->unpack('f4', 16);
			@{$light->{specular}} = $packet->unpack('f4', 16);
			@{$light->{ambient}} = $packet->unpack('f4', 16);
			@{$light->{position}} = $packet->unpack('f3', 12);
			@{$light->{direction}} = $packet->unpack('f3', 12);
			@{$light->{other}} = $packet->unpack('f7', 28);
			($light->{unk1},
			$light->{unk2},
			$light->{name}) = $packet->unpack('VVZ*');
			my $l = 63 - length($light->{name});
			$light->{garb} = $packet->unpack("C$l");
			push @{$self->{lights}}, $light;
		}
	} else {
		$self->{fsl_light_dynamic}->{count} = $packet->resid() / 0x7c;
		fail('wrong size of FSL_LIGHT_DYNAMIC') unless $packet->resid() % 0x7c == 0;
		for (my $i = 0; $i < $self->{fsl_light_dynamic}->{count}; $i++) {
			my $light = {};
			($light->{type}) = $packet->unpack('V', 4);
			@{$light->{diffuse}} = $packet->unpack('f4', 16);
			@{$light->{specular}} = $packet->unpack('f4', 16);
			@{$light->{ambient}} = $packet->unpack('f4', 16);
			@{$light->{position}} = $packet->unpack('f3', 12);
			@{$light->{direction}} = $packet->unpack('f3', 12);
			@{$light->{other}} = $packet->unpack('f7', 28);
			@{$light->{unk}} = $packet->unpack('V5', 20);
			push @{$self->{lights}}, $light;
		}
	}
	fail('there is some data left in packet ['.$packet->resid().']') unless $packet->resid() == 0;
}
sub compile {
	my $self = shift;
	my $data = '';
	if ($self->{version} > 8) {
		foreach my $light (@{$self->{lights}}) {
			$data .= pack('VVf4f4f4f3f3f7', $light->{controller_id}, $light->{type}, @{$light->{diffuse}}, @{$light->{specular}}, @{$light->{ambient}}, @{$light->{position}}, @{$light->{direction}}, @{$light->{other}});
		}
	} elsif ($self->{version} > 5) {
		foreach my $light (@{$self->{lights}}) {
			$data .= pack('Vf4f4f4f3f3f7VVZ*', $light->{type}, @{$light->{diffuse}}, @{$light->{specular}}, @{$light->{ambient}}, @{$light->{position}}, @{$light->{direction}}, @{$light->{other}}, $light->{unk1}, $light->{unk2}, $light->{name});
			for (my $i = 0; $i < (64 - length($light->{name})); $i++) {
				$data .= pack('C', 0xED);
			}
		}
	} else {
		foreach my $light (@{$self->{lights}}) {
			$data .= pack('Vf4f4f4f3f3f7V5', $light->{type}, @{$light->{diffuse}}, @{$light->{specular}}, @{$light->{ambient}}, @{$light->{position}}, @{$light->{direction}}, @{$light->{other}}, @{$light->{unk}});
		}
	}
	$self->{data} = \$data;
}
sub write {
	my $self = shift;
	my ($fh) = @_;
	my $index = chunks::get_index('FSL_LIGHT_DYNAMIC', $self->{version});
	$fh->w_chunk($index, ${$self->{data}});	
}
sub export_ltx {
	my $self = shift;

	my $fh = IO::File->new('FSL_LIGHT_DYNAMIC.ltx', 'w') or fail("FSL_LIGHT_DYNAMIC.ltx: $!\n");	
	my $i = 0;
	foreach my $light (@{$self->{lights}}) {
		print $fh "[$i]\n";
		print $fh "controller_id = $light->{controller_id}\n" if defined $light->{controller_id};
		printf $fh "type = %s\n", lt_names->{$light->{type}};
		printf $fh "diffuse = %f, %f, %f, %f\n", @{$light->{diffuse}};
		printf $fh "specular = %f, %f, %f, %f\n", @{$light->{specular}};
		printf $fh "ambient = %f, %f, %f, %f\n", @{$light->{ambient}};
		printf $fh "position = %f, %f, %f\n", @{$light->{position}};
		printf $fh "direction = %f, %f, %f\n", @{$light->{direction}};
		printf $fh "range = %f\n", @{$light->{other}}[0];
		printf $fh "falloff = %f\n", @{$light->{other}}[1];
		printf $fh "attenuation0 = %f\n", @{$light->{other}}[2];
		printf $fh "attenuation1 = %f\n", @{$light->{other}}[3];
		printf $fh "attenuation2 = %f\n", @{$light->{other}}[4];
		printf $fh "theta = %f\n", @{$light->{other}}[5];
		printf $fh "phi = %f\n", @{$light->{other}}[6];
		print $fh "unk1 = $light->{unk1}\n" if defined $light->{unk1};
		print $fh "unk2 = $light->{unk2}\n" if defined $light->{unk2};
		print $fh "name = $light->{name}\n" if defined $light->{name};
		if (defined @{$light->{unk}}) {
			printf $fh "unk_0 = %s\n", @{$light->{unk}}[0];
			printf $fh "unk_1 = %s\n", @{$light->{unk}}[1];
			printf $fh "unk_2 = %s\n", @{$light->{unk}}[2];
			printf $fh "unk_3 = %s\n", @{$light->{unk}}[3];
			printf $fh "unk_4 = %s\n", @{$light->{unk}}[4];
		}
		print $fh "\n";
		$i++;
	}
	$fh->close();
}
sub import_ltx {
	my $self = shift;

	my $fh = stkutils::ini_file->new('FSL_LIGHT_DYNAMIC.ltx', 'r') or fail("FSL_LIGHT_DYNAMIC.ltx: $!\n");	
	my $len = $#{$fh->{sections_list}} + 1;
	for (my $i = 0; $i < $len; $i++) {
		my $light = {};
		$light->{controller_id} = $fh->value($i, 'controller_id');
		$light->{type} = reverse_lt_names->{$fh->value($i, 'type')};
		@{$light->{diffuse}} = split(/,\s*/, $fh->value($i, 'diffuse'));
		@{$light->{specular}} = split(/,\s*/, $fh->value($i, 'specular'));
		@{$light->{ambient}} = split(/,\s*/, $fh->value($i, 'ambient'));
		@{$light->{position}} = split(/,\s*/, $fh->value($i, 'position'));
		@{$light->{direction}} = split(/,\s*/, $fh->value($i, 'direction'));
		$light->{other}[0] = $fh->value($i, 'range');
		$light->{other}[1] = $fh->value($i, 'falloff');
		$light->{other}[2] = $fh->value($i, 'attenuation0');
		$light->{other}[3] = $fh->value($i, 'attenuation1');
		$light->{other}[4] = $fh->value($i, 'attenuation2');
		$light->{other}[5] = $fh->value($i, 'theta');
		$light->{other}[6] = $fh->value($i, 'phi');
		$light->{unk1} = $fh->value($i, 'unk1');
		$light->{unk2} = $fh->value($i, 'unk2');
		$light->{name} = $fh->value($i, 'name');
		$light->{unk}[0] = $fh->value($i, 'unk_0');
		$light->{unk}[1] = $fh->value($i, 'unk_1');
		$light->{unk}[2] = $fh->value($i, 'unk_2');
		$light->{unk}[3] = $fh->value($i, 'unk_3');
		$light->{unk}[4] = $fh->value($i, 'unk_4');
		push @{$self->{lights}}, $light;
	}
	$fh->close();
}
#########################################################
package fsl_light_key_frames;
use strict;
use stkutils::ini_file;
use stkutils::debug qw(fail);
use stkutils::data_packet;
sub new {
	my $class = shift;
	my $self = {};
	$self->{version} = $_[0];
	$self->{data} = ($_[1] or '');
	bless($self, $class);
	return $self;
}
sub decompile {
	my $self = shift;
	my $packet = stkutils::data_packet->new($self->{data});
	print "decompiling of FSL_LIGHT_KEY_FRAMES not implemented yet\n";
}
sub compile {
	my $self = shift;
	my $data = '';
	print "compiling of FSL_LIGHT_KEY_FRAMES not implemented yet\n";
	$self->{data} = \$data;
}
sub write {
	my $self = shift;
	my ($fh) = @_;
	my $index = chunks::get_index('FSL_LIGHT_KEY_FRAMES', $self->{version});
	$fh->w_chunk($index, ${$self->{data}});	
}
sub export_ltx {
	my $self = shift;

	my $fh = IO::File->new('FSL_LIGHT_KEY_FRAMES.ltx', 'w') or fail("FSL_LIGHT_KEY_FRAMES.ltx: $!\n");
	print "exporting decompiled data of FSL_LIGHT_KEY_FRAMES not implemented yet\n";
	$fh->close();
}
sub import_ltx {
	my $self = shift;

	my $fh = stkutils::ini_file->new('FSL_LIGHT_KEY_FRAMES.ltx', 'r') or fail("FSL_LIGHT_KEY_FRAMES.ltx: $!\n");	
	print "importing decompiled data of FSL_LIGHT_KEY_FRAMES not implemented yet\n";
	$fh->close();
}
#########################################################
package fsl_glows;
use strict;
use stkutils::ini_file;
use stkutils::debug qw(fail);
use stkutils::data_packet;
sub new {
	my $class = shift;
	my $self = {};
	$self->{version} = $_[0];
	$self->{data} = ($_[1] or '');
	bless($self, $class);
	return $self;
}
sub decompile {
	my $self = shift;
	my $packet = stkutils::data_packet->new($self->{data});
	if ($self->{version} > 11) {
		my $count = $packet->resid() / 0x12;
		fail('wrong size of FSL_GLOWS') unless $packet->resid() % 0x12 == 0;
		for (my $i = 0; $i < $count; $i++) {
			my $glow = {};
			@{$glow->{position}} = $packet->unpack('f3', 12);
			($glow->{radius},
			$glow->{shader_index}) = $packet->unpack('fv', 6);
			push @{$self->{glows}}, $glow;
		}
	} else {
		my $count = $packet->resid() / 0x18;
		fail('wrong size of FSL_GLOWS') unless $packet->resid() % 0x18 == 0;
		for (my $i = 0; $i < $count; $i++) {
			my $glow = {};
			@{$glow->{position}} = $packet->unpack('f3', 12);
			($glow->{radius},
			$glow->{texture_index},
			$glow->{shader_index}) = $packet->unpack('fVV', 12);
			push @{$self->{glows}}, $glow;
		}
	}
	fail('there is some data left in packet ['.$packet->resid().']') unless $packet->resid() == 0;
}
sub compile {
	my $self = shift;
	my $data = '';
	if ($self->{version} <= 11) {
		foreach my $glow (@{$self->{glows}}) {
			$data .= pack('f3fVV', @{$glow->{position}}, $glow->{radius}, $glow->{texture_index}, $glow->{shader_index});
		}
	} else {
		foreach my $glow (@{$self->{glows}}) {
			$data .= pack('f3fv', @{$glow->{position}}, $glow->{radius}, $glow->{shader_index});
		}
	}
	$self->{data} = \$data;
}
sub write {
	my $self = shift;
	my ($fh) = @_;
	my $index = chunks::get_index('FSL_GLOWS', $self->{version});
	$fh->w_chunk($index, ${$self->{data}});	
}
sub export_ltx {
	my $self = shift;

	my $fh = IO::File->new('FSL_GLOWS.ltx', 'w') or fail("FSL_GLOWS.ltx: $!\n");	
	my $i = 0;
	foreach my $glow (@{$self->{glows}}) {
		print $fh "[$i]\n";
		printf $fh "position = %f, %f, %f\n", @{$glow->{position}}[0..2];
		printf $fh "radius = %f\n", $glow->{radius};
		print $fh "texture_index = $glow->{texture_index}\n" if $self->{version} <= 11;
		print $fh "shader_index = $glow->{shader_index}\n\n";
		$i++;
	}
	$fh->close();
}
sub import_ltx {
	my $self = shift;

	my $fh = stkutils::ini_file->new('FSL_GLOWS.ltx', 'r') or fail("FSL_GLOWS.ltx: $!\n");	
	my $len = $#{$fh->{sections_list}} + 1;
	for (my $i = 0; $i < $len; $i++) {
		my $glow = {};
		@{$glow->{position}} = split(',\s*', $fh->value($i, 'position'));
		$glow->{radius} = $fh->value($i, 'radius');
		$glow->{texture_index} = $fh->value($i, 'texture_index') if $self->{version} <= 11;
		$glow->{shader_index} = $fh->value($i, 'shader_index');
		push @{$self->{glows}}, $glow;
	}
	$fh->close();
}
#########################################################
package fsl_visuals;
use strict;
use stkutils::ini_file;
use stkutils::debug qw(fail);
use stkutils::data_packet;
sub new {
	my $class = shift;
	my $self = {};
	$self->{version} = $_[0];
	$self->{data} = ($_[1] or '');
	bless($self, $class);
	return $self;
}
sub decompile {
	my $self = shift;
	my ($mode) = @_;
	
	my $fh = stkutils::chunked->new($self->{data}, 'data');
	my $i = 0;
	while(1) {
		my ($index, $size) = $fh->r_chunk_open();
		defined $index or last;
		if ($mode && ($mode eq 'full')) {
			my $visual = stkutils::file::ogf->new();
			$visual->read($fh);
			push @{$self->{visuals}}, $visual;
		}
		$i++;
		$fh->r_chunk_close();
	}
	$self->{vis_count} = $i;
	$fh->close();
}
sub compile {
	my $self = shift;
	my ($mode, $index) = @_;
	my $data = '';
	my $fh = stkutils::chunked->new('', 'data');
	my $i = $index;
	$i = 0 if !defined $index;
	if ($mode && ($mode eq 'full')) {
		foreach my $visual (@{$self->{visuals}}) {
			$fh->w_chunk_open($i);
			$visual->write($fh);
			$fh->w_chunk_close($i);
			$i++;
		}
	}
	$self->{data} = $fh->data();
	$fh->close();
}
sub write {
	my $self = shift;
	my ($fh) = @_;
	my $index = chunks::get_index('FSL_VISUALS', $self->{version});
	$fh->w_chunk($index, ${$self->{data}});	
}
sub export_ltx {
	print "exporting decompiled data of FSL_VISUALS not implemented yet\n";
}
sub import_ltx {
	print "importing decompiled data of FSL_VISUALS not implemented yet\n";
}
#########################################################
package fsl_vertex_buffer;
use strict;
use stkutils::ini_file;
use stkutils::data_packet;
use stkutils::debug qw(fail);
use constant type_names => {
	1	=> 'FLOAT2',
	2	=> 'FLOAT3',
	3	=> 'FLOAT4',
	4	=> 'D3DCOLOR',
	6	=> 'SHORT2',
	7	=> 'SHORT4',
	17	=> 'UNUSED',
};
use constant method_names => {
	0	=> 'DEFAULT',
	1	=> 'PARTIALU',
	2	=> 'PARTIALV',
	3	=> 'CROSSUV',
	4	=> 'UV',
};
use constant usage_names => {
	0	=> 'POSITION',
	1	=> 'BLENDWEIGHT',
	2	=> 'BLENDINDICES',
	3	=> 'NORMAL',
	4	=> 'PSIZE',
	5	=> 'TEXCOORD',
	6	=> 'TANGENT',
	7	=> 'BINORMAL',
	8	=> 'TESSFACTOR',
	9	=> 'POSITIONT',
	10	=> 'COLOR',
	11	=> 'FOG',
	12	=> 'DEPTH',
	12	=> 'SAMPLE',
};
sub new {
	my $class = shift;
	my $self = {};
	$self->{version} = $_[0];
	$self->{data} = ($_[1] or '');
	bless($self, $class);
	return $self;
}
sub decompile {
	my $self = shift;
	my $mode = shift;
	my $packet = stkutils::data_packet->new($self->{data});
	($self->{vbufs_count}) = $packet->unpack('V', 4);
	if ($mode && ($mode eq 'full')) {
		if ($self->{version} > 8) {
			for (my $i = 0; $i < $self->{vbufs_count}; $i++) {
				my $vertex_buffer = {};
				my $vertice_count;
				my @type;
				my @usage;
				for (my $j = 0; ; $j++) {
					my $d3d9ve = {};
					($d3d9ve->{stream},
					 $d3d9ve->{offset},
					 $d3d9ve->{type},
					 $d3d9ve->{method},
					 $d3d9ve->{usage},
					 $d3d9ve->{usage_index}) = $packet->unpack('v2C4', 8);
#					 print "$i:$d3d9ve->{method}\n";
					 push @type, $d3d9ve->{type};
					 push @usage, $d3d9ve->{usage};
					 push @{$vertex_buffer->{d3d9vertexelements}}, $d3d9ve;
					if ($d3d9ve->{type} == 0x11) {
						$vertice_count = $j;
						last;
					}
				}
				my ($vert_count) = $packet->unpack('V', 4);
				for (my $j = 0; $j < $vert_count; $j++) {
					my $vertex = {};
					my $texcoord = 0;
					for (my $z = 0; $z < $vertice_count; $z++) {
						SWITCH: {
							(usage_names->{$usage[$z]} eq 'POSITION') && do{@{$vertex->{points}} = $packet->unpack('f3', 12); last SWITCH;};
							(usage_names->{$usage[$z]} eq 'NORMAL') && do{@{$vertex->{normals}} = $packet->unpack('C4', 4); last SWITCH;};
							(usage_names->{$usage[$z]} eq 'TEXCOORD') && do{
								SWITCH: {
									(type_names->{$type[$z]} eq 'FLOAT2') && do{
										if (++$texcoord == 1) {
											@{$vertex->{texcoords}} = $packet->unpack('f2', 8);
											print "@{$vertex->{texcoords}}\n";
										} else {
											@{$vertex->{lightmaps}} = $packet->unpack('f2', 8);
											print "@{$vertex->{lightmaps}}\n";
										}; 
										
										last SWITCH;};
									(type_names->{$type[$z]} eq 'SHORT2') && do{
											if (++$texcoord == 1) {
												@{$vertex->{texcoords}} = $packet->unpack('v2', 4);
											} else {
												@{$vertex->{lightmaps}} = $packet->unpack('v2', 4);
											}; 
											last SWITCH;};
									(type_names->{$type[$z]} eq 'SHORT4') && do{
										@{$vertex->{texcoords}} = $packet->unpack('v2', 4);
										@{$vertex->{lightmaps}} = $packet->unpack('v2', 4);
										last SWITCH;};
									fail('unsupported type ['.$type[$z].']');
								}; last SWITCH;
							};
							(usage_names->{$usage[$z]} eq 'TANGENT') && do{@{$vertex->{tangents}} = $packet->unpack('C4', 4); last SWITCH;};
							(usage_names->{$usage[$z]} eq 'BINORMAL') && do{@{$vertex->{binormals}} = $packet->unpack('C4', 4); last SWITCH;};
							(usage_names->{$usage[$z]} eq 'COLOR') && do{@{$vertex->{colors}} = $packet->unpack('C4', 4); last SWITCH;};
							fail('unsupported usage ['.$usage[$z].']');
						}
					}
					push @{$vertex_buffer->{vertices}}, $vertex;
				}
	#			print $packet->{pos}."\n";
				push @{$self->{vbufs}}, $vertex_buffer;
			}
		} else {
			for (my $i = 0; $i < $self->{vbufs_count}; $i++) {
				my $set = {};
				($set->{fvf}, $set->{n}) = $packet->unpack('VV', 8);
				push @{$self->{vbufs}}, $set;
			}
		}
		fail('there is some data left in packet ['.$packet->resid().']') unless $packet->resid() == 0;
	}
}
sub compile {
	my $self = shift;
	my $data = '';
	$data .= pack('V', $#{$self->{vbufs}} + 1);
	if ($self->{version} > 8) {
		foreach my $set (@{$self->{vbufs}}) {
			my @type;
			my @usage;
			foreach my $d3d9ve (@{$set->{d3d9vertexelements}}) {
				push @type, $d3d9ve->{type};
				push @usage, $d3d9ve->{usage};
				$data .= pack('v2C4', $d3d9ve->{stream}, $d3d9ve->{offset}, $d3d9ve->{type}, $d3d9ve->{method}, $d3d9ve->{usage}, $d3d9ve->{usage_index});
			}
			$data .= pack('V', $#{$set->{vertices}} + 1);
			my $vert_count = $#{$set->{d3d9vertexelements}};
			foreach my $vertex (@{$set->{vertices}}) {
				my $packet = stkutils::data_packet->new();
				my $texcoord = 0;
				for (my $z = 0; $z < $vert_count; $z++) {	
					SWITCH: {
						(usage_names->{$usage[$z]} eq 'POSITION') && do{$packet->pack('f3', @{$vertex->{points}}); last SWITCH;};
						(usage_names->{$usage[$z]} eq 'NORMAL') && do{$packet->pack('C4', @{$vertex->{normals}}); last SWITCH;};
						(usage_names->{$usage[$z]} eq 'TEXCOORD') && do{
							SWITCH: {
								(type_names->{$type[$z]} eq 'FLOAT2') && do{
									if (++$texcoord == 1) {
										$packet->pack('f2', @{$vertex->{texcoords}});
									} else {
										$packet->pack('f2', @{$vertex->{lightmaps}});
									}; 
									last SWITCH;};
								(type_names->{$type[$z]} eq 'SHORT2') && do{
									if (++$texcoord == 1) {
										$packet->pack('v2', @{$vertex->{texcoords}});
									} else {
										$packet->pack('v2', @{$vertex->{lightmaps}});
									}; 
									last SWITCH;};
								(type_names->{$type[$z]} eq 'SHORT4') && do{
									$packet->pack('v2', @{$vertex->{texcoords}});
									$packet->pack('v2', @{$vertex->{lightmaps}});
									last SWITCH;};
								fail('unsupported type ['.$type[$z].']');
							}; last SWITCH;
						};
						(usage_names->{$usage[$z]} eq 'TANGENT') && do{$packet->pack('C4', @{$vertex->{tangents}}); last SWITCH;};
						(usage_names->{$usage[$z]} eq 'BINORMAL') && do{$packet->pack('C4', @{$vertex->{binormals}}); last SWITCH;};
						(usage_names->{$usage[$z]} eq 'COLOR') && do{$packet->pack('C4', @{$vertex->{colors}}); last SWITCH;};
						fail('unsupported usage ['.$usage[$z].']');
					}
				}
				$data .= $packet->data();
			}
		}
	} else {
		foreach my $set (@{$self->{vbufs}}) {
			$data .= pack('VV', $set->{fvf}, $set->{n});
		}
	}
	$self->{data} = \$data;
}
sub write {
	my $self = shift;
	my ($fh) = @_;
	my $index = chunks::get_index('FSL_VB', $self->{version});
	$fh->w_chunk($index, ${$self->{data}});	
}
sub export_ltx {
	print "exporting decompiled data of FSL_VB not implemented\n";
}
sub import_ltx {
	print "importing decompiled data of FSL_VB not implemented\n";
}
#########################################################
package fsl_swis;
use strict;
use stkutils::ini_file;
use stkutils::data_packet;
use stkutils::debug qw(fail);
sub new {
	my $class = shift;
	my $self = {};
	$self->{version} = $_[0];
	$self->{data} = ($_[1] or '');
	bless($self, $class);
	return $self;
}
sub decompile {
	my $self = shift;
	my $mode = shift;
	my $packet = stkutils::data_packet->new($self->{data});
	($self->{swibufs_count}) = $packet->unpack('V', 4);
	if ($mode && ($mode eq 'full')) {
		for (my $i = 0; $i < $self->{swibufs_count}; $i++) {
			my $swibuf = {};
			@{$swibuf->{reserved}} = $packet->unpack('V4', 16);
			($swibuf->{sw_count}) = $packet->unpack('V', 4);
			for (my $j = 0; $j < $swibuf->{sw_count}; $j++) {
				my $slide_window = {};
				($slide_window->{offset},
				$slide_window->{num_tris},
				$slide_window->{num_verts}) = $packet->unpack('lvv', 8);
				push @{$swibuf->{slide_windows}}, $slide_window;
			}
			push @{$self->{swibufs}}, $swibuf;
		}
		fail('there is some data left in packet ['.$packet->resid().']') unless $packet->resid() == 0;
	}
}
sub compile {
	my $self = shift;
	my $data = '';
	$data .= pack('V', $#{$self->{swibufs}} + 1);
	foreach my $swibuf (@{$self->{swibufs}}) {
		$data .= pack('V4V', @{$swibuf->{reserved}}, $swibuf->{sw_count});
		foreach my $window (@{$swibuf->{slide_windows}}) {
			$data .= pack('lvv', $window->{offset}, $window->{num_tris}, $window->{num_verts});
		}
	}
	$self->{data} = \$data;
}
sub write {
	my $self = shift;
	my ($fh) = @_;
	my $index = chunks::get_index('FSL_SWIS', $self->{version});
	$fh->w_chunk($index, ${$self->{data}});	
}
sub export_ltx {
	print "exporting decompiled data of FSL_SWIS not implemented\n";
}
sub import_ltx {
	print "importing decompiled data of FSL_SWIS not implemented\n";
}
#########################################################
package fsl_index_buffer;
use strict;
use stkutils::ini_file;
use stkutils::debug qw(fail);
use stkutils::data_packet;
sub new {
	my $class = shift;
	my $self = {};
	$self->{version} = $_[0];
	$self->{data} = ($_[1] or '');
	bless($self, $class);
	return $self;
}
sub decompile {
	my $self = shift;
	my $mode = shift;
	my $packet = stkutils::data_packet->new($self->{data});
	($self->{ibufs_count}) = $packet->unpack('V', 4);
	if ($mode && ($mode eq 'full')) {
		for (my $i = 0; $i < $self->{ibufs_count}; $i++) {
			my ($count) = $packet->unpack('V', 4);
			my $buffer = {};
			@{$buffer->{indices}} = $packet->unpack("v$count");
			push @{$self->{ibufs}}, $buffer;
		}
		fail('there is some data left in packet ['.$packet->resid().']') unless $packet->resid() == 0;
	}
}
sub compile {
	my $self = shift;
	my $data = '';
	$data .= pack('V', $#{$self->{ibufs}} + 1);
	foreach my $ibuf (@{$self->{ibufs}}) {
		my $count = $#{$ibuf->{indices}} + 1;
		$data .= pack('V', $count);
		$data .= pack("v$count", @{$ibuf->{indices}});
	}
	$self->{data} = \$data;
}
sub write {
	my $self = shift;
	my ($fh) = @_;
	my $index = chunks::get_index('FSL_IB', $self->{version});
	$fh->w_chunk($index, ${$self->{data}});	
}
sub export_ltx {
	print "exporting decompiled data of FSL_IB not implemented\n";
}
sub import_ltx {
	print "importing decompiled data of FSL_IB not implemented\n";
}
#########################################################
package fsl_textures;
use strict;
use stkutils::ini_file;
use stkutils::debug qw(fail);
use stkutils::data_packet;
sub new {
	my $class = shift;
	my $self = {};
	$self->{version} = $_[0];
	$self->{data} = ($_[1] or '');
	bless($self, $class);
	return $self;
}
sub decompile {
	my $self = shift;
	my $packet = stkutils::data_packet->new($self->{data});
	my ($count) = $packet->unpack('V', 4);
	@{$self->{textures}} = $packet->unpack("(Z*)$count");
}
sub compile {
	my $self = shift;
	my $data = '';
	$data = pack('V', $self->{count});
	for (my $i = 0; $i < $self->{count}; $i++) {
		$data .= pack('Z*', $self->{textures}[$i]);
	}
	$self->{data} = \$data;
}
sub write {
	my $self = shift;
	my ($fh) = @_;
	$fh->w_chunk(2, ${$self->{data}});
}
sub export_ltx {
	my $self = shift;
	
	my $fh = IO::File->new('FSL_TEXTURES.ltx', 'w') or fail("FSL_TEXTURES.ltx: $!\n");	
	my $len = $#{$self->{textures}} + 1;
	for (my $i = 0; $i < $len; $i++) {
		print $fh "[$i]\n";
		print $fh "texture = $self->{textures}[$i]\n";
	}
	$fh->close();
}
sub import_ltx {
	my $self = shift;
	
	my $fh = stkutils::ini_file->new('FSL_TEXTURES.ltx', 'r') or fail("FSL_TEXTURES.ltx: $!\n");	
	for (my $i = 0; $i < $#{$fh->{sections_list}} + 1; $i++) {
		$self->{textures}[$i] = $fh->value($i, 'texture');
	}
	$self->{count} = $#{$fh->{sections_list}} + 1;
	$fh->close();
}
#########################################################
package fsl_shaders;
use strict;
use stkutils::ini_file;
use stkutils::debug qw(fail);
use stkutils::data_packet;
sub new {
	my $class = shift;
	my $self = {};
	$self->{version} = $_[0];
	$self->{data} = ($_[1] or '');
	bless($self, $class);
	return $self;
}
sub decompile {
	my $self = shift;
	my $packet = stkutils::data_packet->new($self->{data});
	my ($count) = $packet->unpack('V', 4);
	for (my $i = 0; $i < $count; $i++) {
		my ($str) = $packet->unpack('Z*');
		if ($self->{version} > 11) {
			($self->{shaders}[$i], $self->{textures}[$i]) = split /\//, $str; 
		} else {
			$self->{textures}[$i] = $str;
		}
	}
}
sub compile {
	my $self = shift;
	my $data = '';
	my $count = $#{$self->{textures}} + 1;
	$data = pack('V', $count);
	$data .= "\0" if $self->{version} > 10;
	if ($self->{version} > 11) {
		for (my $i = 1; $i < $count; $i++) {
			$data .= pack('Z*', join ('/', $self->{shaders}[$i], $self->{textures}[$i]));
		}
	} else {
		my $first_rec = 0;
		if ($self->{version} > 10) {
			$first_rec = 1;
		}		
		for (my $i = $first_rec; $i < $count; $i++) {
			$data .= pack('Z*', $self->{textures}[$i]);
		}	
	}
	$self->{data} = \$data;
}
sub write {
	my $self = shift;
	my ($fh) = @_;
	my $index = chunks::get_index('FSL_SHADERS', $self->{version});
	$fh->w_chunk($index, ${$self->{data}});
}
sub export_ltx {
	my $self = shift;

	my $fh = IO::File->new('FSL_SHADERS.ltx', 'w') or fail("FSL_SHADERS.ltx: $!\n");	
	my $count = $#{$self->{textures}} + 1;
	my $first_rec = 0;
	if ($self->{version} > 10) {
		$first_rec = 1;
	}
	for (my $i = $first_rec; $i < $count; $i++) {
		print $fh "[$i]\n";
		print $fh "shader = $self->{shaders}[$i]\n" if $self->{version} > 11;
		print $fh "textures = $self->{textures}[$i]\n";
		print $fh "\n";
	}
	$fh->close();
}
sub import_ltx {
	my $self = shift;

	my $fh = stkutils::ini_file->new('FSL_SHADERS.ltx', 'r') or fail("FSL_SHADERS.ltx: $!\n");	
	my $first_rec = 0;
	if ($self->{version} > 10) {
		$first_rec = 1;
	}
	my $len = $#{$fh->{sections_list}} + 1 + $first_rec;
	for (my $i = $first_rec; $i < $len; $i++) {
		$self->{shaders}[$i] = $fh->value($i, 'shader') if $self->{version} > 11;
		$self->{textures}[$i] = $fh->value($i, 'textures');
	}
	$fh->close();
}
#########################################################
package fsl_sectors;
use strict;
use stkutils::ini_file;
use stkutils::debug qw(fail);
use stkutils::data_packet;
sub new {
	my $class = shift;
	my $self = {};
	$self->{version} = $_[0];
	$self->{data} = ($_[1] or '');
	bless($self, $class);
	return $self;
}
sub decompile {
	my $self = shift;
	my $mode = shift;
	my $cf = stkutils::chunked->new($self->{data}, 'data');
	my $i = 0;
	while (1) {
		my ($index, $size) = $cf->r_chunk_open();
		defined $index or last;
		my $sector = {};
		if ($mode && ($mode eq 'full')) {
			while (1) {
				my ($id, $size) = $cf->r_chunk_open();
				defined $id or last;
				SWITCH: {
					$id == 0x1 && do { decompile_portals($sector, $cf); last SWITCH; };
					$id == 0x2 && do { decompile_root($sector, $cf); last SWITCH; };
					fail ("unexpected chunk $id size $size in $index\n");
				}
				$cf->r_chunk_close();
			}
			push @{$self->{sectors}}, $sector;
		}
		$i++;
		$cf->r_chunk_close();
	}
	$self->{sector_count} = $i;
	$cf->close();
}
sub decompile_portals {
	my $self = shift;
	my ($cf) = @_;
	my $packet = stkutils::data_packet->new($cf->r_chunk_data());
	if ($packet->resid() == 0) {return;}
	my $count = $packet->resid() / 2;
	fail('wrong size of portals in FSL_SECTORS') unless $packet->resid() % 2 == 0;
	@{$self->{portals}} = $packet->unpack("v$count");
	fail('there is some data left in packet ['.$packet->resid().']') unless $packet->resid() == 0;
}
sub decompile_root {
	my $self = shift;
	my ($cf) = @_;
	my $packet = stkutils::data_packet->new($cf->r_chunk_data());
	($self->{root}) = $packet->unpack('V', 4);
	fail('there is some data left in packet ['.$packet->resid().']') unless $packet->resid() == 0;
}
sub compile {
	my $self = shift;
	my $cf = stkutils::chunked->new('', 'data');
	my $i = $_[0];
	$i = 0 if $#_ == -1;
	foreach my $sector (@{$self->{sectors}}) {
		$cf->w_chunk_open($i);
		$cf->w_chunk(0x2, pack('V', $sector->{root}));
		$cf->w_chunk_open(0x1);
		foreach my $portal (@{$sector->{portals}}) {
			$cf->w_chunk_data(pack('v', $portal));
		}
		$cf->w_chunk_close();
		$cf->w_chunk_close();
		$i++;
	}
	$self->{data} = $cf->data();
}
sub write {
	my $self = shift;
	my ($fh) = @_;
	my $index = chunks::get_index('FSL_SECTORS', $self->{version});
	$fh->w_chunk($index, ${$self->{data}});	
}
sub export_ltx {
	my $self = shift;

	my $fh = IO::File->new('FSL_SECTORS.ltx', 'w') or fail("FSL_SECTORS.ltx: $!\n");	
	my $i = 0;
	foreach my $sector (@{$self->{sectors}}) {
		print $fh "[$i]\n";
		my $j = 0;
		my $portal_count = $#{$sector->{portals}} + 1;
		print $fh "portals_count = $portal_count\n";
		foreach my $portal (@{$sector->{portals}}) {
			print $fh "portal_$j = $portal\n";
			$j++;
		}
		print $fh "root = $sector->{root}\n\n";
		$i++;
	}
	$fh->close();
}
sub import_ltx {
	my $self = shift;

	my $fh = stkutils::ini_file->new('FSL_SECTORS.ltx', 'r') or fail("FSL_SECTORS.ltx: $!\n");	
	my $len = $#{$fh->{sections_list}} + 1;
	for (my $i = 0; $i < $len; $i++) {
		my $sector = {};
		my $portals_count = $fh->value($i, 'portals_count');
		for (my $j = 0; $j < $portals_count; $j++) {
			@{$sector->{portals}}[$j] = $fh->value($i, "portal_$j");
		}
		$sector->{root} = $fh->value($i, 'root');
		push @{$self->{sectors}}, $sector;
	}
	$fh->close();
}
#########################################################
package chunks;
use constant chunk_table => (
	{name => 'FSL_HEADER', version => 0, chunk_index => 0x1},
	{name => 'FSL_TEXTURES', version => 0, chunk_index => 0x2},
	{name => 'FSL_SHADERS', version => 5, chunk_index => 0x2},
	{name => 'FSL_SHADERS', version => 0, chunk_index => 0x3},
	{name => 'FSL_VISUALS', version => 5, chunk_index => 0x3},
	{name => 'FSL_VISUALS', version => 0, chunk_index => 0x4},
	{name => 'FSL_PORTALS', version => 9, chunk_index => 0x4},
	{name => 'FSL_PORTALS', version => 5, chunk_index => 0x6},
	{name => 'FSL_PORTALS', version => 0, chunk_index => 0x7},
	{name => 'FSL_CFORM', version => 5, chunk_index => 0x5},
	{name => 'FSL_CFORM', version => 0, chunk_index => 0x6},
	{name => 'FSL_SHADER_CONSTANT', version => 8, chunk_index => 0x7},
	{name => 'FSL_LIGHT_KEY_FRAMES', version => 0, chunk_index => 0x9},
	{name => 'FSL_LIGHT_DYNAMIC', version => 9, chunk_index => 0x6},
	{name => 'FSL_LIGHT_DYNAMIC', version => 8, chunk_index => 0x8},
	{name => 'FSL_LIGHT_DYNAMIC', version => 5, chunk_index => 0x7},
	{name => 'FSL_LIGHT_DYNAMIC', version => 0, chunk_index => 0x8},
	{name => 'FSL_GLOWS', version => 9, chunk_index => 0x7},
	{name => 'FSL_GLOWS', version => 5, chunk_index => 0x9},
	{name => 'FSL_GLOWS', version => 0, chunk_index => 0xa},
	{name => 'FSL_SECTORS', version => 9, chunk_index => 0x8},
	{name => 'FSL_SECTORS', version => 5, chunk_index => 0xa},
	{name => 'FSL_SECTORS', version => 0, chunk_index => 0xb},
	{name => 'FSL_VB', version => 12, chunk_index => 0x9},
	{name => 'FSL_VB', version => 9, chunk_index => 0xa},
	{name => 'FSL_VB', version => 8, chunk_index => 0xc},
	{name => 'FSL_VB', version => 5, chunk_index => 0x4},
	{name => 'FSL_VB', version => 0, chunk_index => 0x5},
	{name => 'FSL_IB', version => 12, chunk_index => 0xa},
	{name => 'FSL_IB', version => 9, chunk_index => 0x9},
	{name => 'FSL_IB', version => 8, chunk_index => 0xb},
	{name => 'FSL_SWIS', version => 9, chunk_index => 0xb},
);
use constant reverse_chunk_table => (
	{name => 'FSL_HEADER', version => 0, chunk_index => 0x1},
	{name => 'FSL_SHADERS', version => 5, chunk_index => 0x2},
	{name => 'FSL_TEXTURES', version => 0, chunk_index => 0x2},
	{name => 'FSL_VISUALS', version => 5, chunk_index => 0x3},
	{name => 'FSL_SHADERS', version => 0, chunk_index => 0x3},
	{name => 'FSL_PORTALS', version => 9, chunk_index => 0x4},
	{name => 'FSL_VB', version => 5, chunk_index => 0x4},
	{name => 'FSL_VISUALS', version => 0, chunk_index => 0x4},
	{name => 'FSL_CFORM', version => 5, chunk_index => 0x5},
	{name => 'FSL_VB', version => 0, chunk_index => 0x5},
	{name => 'FSL_LIGHT_DYNAMIC', version => 9, chunk_index => 0x6},
	{name => 'FSL_PORTALS', version => 5, chunk_index => 0x6},
	{name => 'FSL_CFORM', version => 0, chunk_index => 0x6},
	{name => 'FSL_GLOWS', version => 9, chunk_index => 0x7},
	{name => 'FSL_SHADER_CONSTANT', version => 8, chunk_index => 0x7},
	{name => 'FSL_LIGHT_DYNAMIC', version => 5, chunk_index => 0x7},
	{name => 'FSL_PORTALS', version => 0, chunk_index => 0x7},
	{name => 'FSL_SECTORS', version => 9, chunk_index => 0x8},
	{name => 'FSL_LIGHT_DYNAMIC', version => 8, chunk_index => 0x8},
	{name => 'FSL_LIGHT_DYNAMIC', version => 0, chunk_index => 0x8},
	{name => 'FSL_VB', version => 12, chunk_index => 0x9},
	{name => 'FSL_IB', version => 9, chunk_index => 0x9},
	{name => 'FSL_GLOWS', version => 5, chunk_index => 0x9},
	{name => 'FSL_LIGHT_KEY_FRAMES', version => 0, chunk_index => 0x9},
	{name => 'FSL_IB', version => 12, chunk_index => 0xa},
	{name => 'FSL_VB', version => 9, chunk_index => 0xa},
	{name => 'FSL_SECTORS', version => 5, chunk_index => 0xa},
	{name => 'FSL_GLOWS', version => 0, chunk_index => 0xa},
	{name => 'FSL_SWIS', version => 9, chunk_index => 0xb},
	{name => 'FSL_IB', version => 5, chunk_index => 0xb},
	{name => 'FSL_SECTORS', version => 0, chunk_index => 0xb},
	{name => 'FSL_VB', version => 8, chunk_index => 0xc},
);
sub get_index {
	foreach my $chunk (chunk_table) {
		if (($_[0] eq $chunk->{name}) && ($_[1] > $chunk->{version})) {
			return $chunk->{chunk_index};
		}
	}
	return undef;
}
sub get_name {
	if ($_[0] & 0x80000000) {
		return 'none';
	}
	foreach my $chunk (reverse_chunk_table) {
		if (($_[0] == $chunk->{chunk_index}) && ($_[1] > $chunk->{version})) {
			return $chunk->{name};
		}
	}
	return undef;
}
#########################################################
package compressed;
use strict;
use IO::File;
use stkutils::debug qw(fail);
sub new {
	my $class = shift;
	my $self = {};
	$self->{version} = $_[0];
	bless($self, $class);
	return $self;
}
sub add {
	my $self = shift;
	$self->{chunks::get_name($_[0], $self->{version})} = $_[1];
}
sub write {
	my $self = shift;
	my ($index, $fh) = @_;
	my $ind = 0x80000000 + $index;
	$fh->w_chunk($ind, ${$self->{chunks::get_name($index, $self->{version})}});	
}
sub export {
	my $self = shift;
	my ($name) = @_;
	return if $name eq 'version';
	my $outf = IO::File->new('COMPRESSED_'.$name.'.bin', 'w') or fail("COMPRESSED_$name.bin: $!\n");	
	binmode $outf;
	$outf->write(${$self->{$name}}, length(${$self->{$name}}));
	$outf->close();
}
sub import {
	my $self = shift;
	my ($name) = @_;
	my $chunk;
	if (defined $name && $name =~ /^(COMPRESSED)_(\w+)/) {
		$chunk = $2;
	} else {
		fail();
	}
	my $fh = IO::File->new($name, 'r') or fail("$name: $!\n");	
	binmode $fh;
	my $data = '';
	$fh->read($data, ($fh->stat())[7]);
	$fh->close();
	$self->{$chunk} = \$data;
}
###########################################################
1;