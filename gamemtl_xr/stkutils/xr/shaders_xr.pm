# S.T.A.L.K.E.R. shaders.xr handling module
# Update history: 
#	01/09/2012 - initial release
##############################################
package stkutils::xr::shaders_xr;
use strict;
use stkutils::data_packet;
use stkutils::ini_file;
use stkutils::math;
use stkutils::debug qw(fail warn);
use stkutils::utils qw(get_filelist get_path write_file read_file);
use File::Path;

use constant SHADERS_CHUNK_CONSTANTS => 0;
use constant SHADERS_CHUNK_MATRICES => 1;
use constant SHADERS_CHUNK_BLENDERS => 2;
use constant SHADERS_CHUNK_NAMES => 3;

# enum WaveForm::EFunction
use constant fCONSTANT => 0;
use constant fSIN => 1;
use constant fTRIANGLE => 2;
use constant fSQUARE => 3;
use constant fSAWTOOTH => 4;
use constant fINVSAWTOOTH => 5;
use constant fFORCE32 => 0xFFFFFFFF;

sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;
	return $self;
}
sub read {
	my $self = shift;
	my ($CDH, $mode) = @_;
	print "reading...\n";
	fail('unsuported mode '.$mode) unless ($mode eq 'ltx') or ($mode eq 'bin');
	while (1) {
		my ($index, $size) = $CDH->r_chunk_open();
		defined $index or last;
		SWITCH: {
			$index == SHADERS_CHUNK_CONSTANTS && do{$self->read_constants($CDH, $mode);last SWITCH;};
			$index == SHADERS_CHUNK_MATRICES && do{$self->read_matrices($CDH, $mode);last SWITCH;};
			$index == SHADERS_CHUNK_BLENDERS && do{$self->read_blenders($CDH, $mode);last SWITCH;};
			$index == SHADERS_CHUNK_NAMES && do{$self->read_names($CDH);last SWITCH;};
			fail('unknown chunk index '.$index);
		}
		$CDH->r_chunk_close();
	}
	$CDH->close();
}
sub read_constants {
	my $self = shift;
	my ($CDH, $mode) = @_;	
	print "	constants\n";
	my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
	if ($mode && ($mode eq 'bin')) {
		$self->{raw_constants} = \$packet->data();
	} else {
		while($packet->resid() > 0) {
			my $constant = {};
			($constant->{name}) = $packet->unpack('Z*');
			for (my $i = 0; $i < 4; $i++) {
				my $waveform = stkutils::math->create('waveform');
				$waveform->set($packet->unpack('Vf4', 20));
				push @{$constant->{waveforms}}, $waveform;
			}
			push @{$self->{constants}}, $constant;
		}
		fail('there is some data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
	}
}
sub read_matrices {
	my $self = shift;
	my ($CDH, $mode) = @_;	
	print "	matrices\n";
	my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
	if ($mode && ($mode eq 'bin')) {
		$self->{raw_matrices} = \$packet->data();
	} else {
		while($packet->resid() > 0) {
			my $matrix = {};
			($matrix->{name}, $matrix->{dwmode}, $matrix->{tcm}) = $packet->unpack('Z*VV');
			$matrix->{scaleU} = stkutils::math->create('waveform');
			$matrix->{scaleU}->set($packet->unpack('Vf4', 20));
			$matrix->{scaleV} = stkutils::math->create('waveform');
			$matrix->{scaleV}->set($packet->unpack('Vf4', 20));
			$matrix->{rotate} = stkutils::math->create('waveform');
			$matrix->{rotate}->set($packet->unpack('Vf4', 20));
			$matrix->{scrollU} = stkutils::math->create('waveform');
			$matrix->{scrollU}->set($packet->unpack('Vf4', 20));
			$matrix->{scrollV} = stkutils::math->create('waveform');
			$matrix->{scrollV}->set($packet->unpack('Vf4', 20));
			push @{$self->{matrices}}, $matrix;
		}
		fail('there is some data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
	}
}
sub read_blenders {
	my $self = shift;
	my ($CDH, $mode) = @_;	
	print "	blenders\n";
	while (1) {
		my ($index, $size) = $CDH->r_chunk_open();
		defined $index or last;
		if ($mode && ($mode eq 'bin')) {
			push @{$self->{blenders}}, $CDH->r_chunk_data();
		} else {
			my $blender = {};
			my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
			($blender->{cls}, $blender->{name}) = $packet->unpack('a[8]Z*');
			$blender->{cls} = reverse $blender->{cls};
#			print "$blender->{name}: $blender->{cls}\n";
			$packet->pos(136);
			($blender->{computer}) = $packet->unpack('Z*');
			$packet->pos(168);
			($blender->{ctime}, $blender->{version}) = $packet->unpack('Vv', 6);
			$packet->pos(176);
			SWITCH: {
				(($blender->{cls} eq 'LmBmmD  ') 																							#CBlender_BmmD
				|| ($blender->{cls} eq 'BmmDold ')) && do {bless ($blender, 'CBlender_BmmD'); $blender->read($packet); last SWITCH;};
				(($blender->{cls} eq 'MODELEbB') 																							#CBlender_Model_EbB
				|| ($blender->{cls} eq 'LmEbB   ')) && do {bless ($blender, 'CBlender_EbB'); $blender->read($packet); last SWITCH;};		#CBlender_LmEbB
				($blender->{cls} eq 'D_STILL ') && do {bless ($blender, 'CBlender_Detail_Still'); $blender->read($packet); last SWITCH;};
				($blender->{cls} eq 'D_TREE  ') && do {bless ($blender, 'CBlender_Tree'); $blender->read($packet); last SWITCH;};
				($blender->{cls} eq 'LM_AREF ') && do {bless ($blender, 'CBlender_deffer_aref'); $blender->read($packet); last SWITCH;};
				($blender->{cls} eq 'V_AREF  ') && do {bless ($blender, 'CBlender_Vertex_aref'); $blender->read($packet); last SWITCH;};
				($blender->{cls} eq 'MODEL   ') && do {bless ($blender, 'CBlender_deffer_model'); $blender->read($packet); last SWITCH;};
				(($blender->{cls} eq 'E_SEL   ') 																							#CBlender_Editor_Selection
				|| ($blender->{cls} eq 'E_WIRE  ')) && do {bless ($blender, 'CBlender_Editor'); $blender->read($packet); last SWITCH;};		#CBlender_Editor_Wire
				($blender->{cls} eq 'PARTICLE') && do {bless ($blender, 'CBlender_Particle'); $blender->read($packet); last SWITCH;};
				($blender->{cls} eq 'S_SET   ') && do {bless ($blender, 'CBlender_Screen_SET'); $blender->read($packet); last SWITCH;};
				(($blender->{cls} eq 'BLUR    ')																							#CBlender_Blur, 		R1 only
				|| ($blender->{cls} eq 'LM      ') 																							#CBlender_default,		R1 only
				|| ($blender->{cls} eq 'SH_WORLD')																							#CBlender_ShWorld, 		R1 only
				|| ($blender->{cls} eq 'S_GRAY  ')
				|| ($blender->{cls} eq 'V       ')) && do {bless ($blender, 'CBlender_Tesselation'); $blender->read($packet); last SWITCH;};			
				warn('unsupported cls '.$blender->{cls}); next;
			}
			push @{$self->{blenders}}, $blender;
			fail('there is some data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
		}
		$CDH->r_chunk_close();
	}
}
sub read_names { 
	my $self = shift;
	my ($CDH) = @_;	
	print "	names\n";
	my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
	my ($count) = $packet->unpack('V', 4);
	for (my $i = 0; $i < $count; $i++) {
		push @{$self->{names}}, $packet->unpack('Z*');
	}
	fail('there is some data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
}
sub write {
	my $self = shift;
	my ($CDH, $mode) = @_;
	print "writing...\n";
	fail('unsuported mode '.$mode) unless ($mode eq 'ltx') or ($mode eq 'bin');
	
	$self->write_constants($CDH, $mode);
	$self->write_matrices($CDH, $mode);
	$self->write_blenders($CDH, $mode);
	$self->write_names($CDH);
}
sub write_constants {
	my $self = shift;
	my ($CDH, $mode) = @_;	
	print "	constants\n";
	if ($mode && ($mode eq 'bin')) {
		$CDH->w_chunk(SHADERS_CHUNK_CONSTANTS, ${$self->{raw_constants}});
	} else {
		$CDH->w_chunk_open(SHADERS_CHUNK_CONSTANTS);
		foreach my $constant (@{$self->{constants}}) {
			$CDH->w_chunk_data(pack('Z*', $constant->{name}));
			for (my $i = 0; $i < 4; $i++) {
				$CDH->w_chunk_data(pack('Vf4', $constant->{waveforms}[$i]->get()));
			}
		}
		$CDH->w_chunk_close();
	}
}
sub write_matrices {
	my $self = shift;
	my ($CDH, $mode) = @_;	
	print "	matrices\n";
	if ($mode && ($mode eq 'bin')) {
		$CDH->w_chunk(SHADERS_CHUNK_MATRICES, ${$self->{raw_matrices}});
	} else {
		$CDH->w_chunk_open(SHADERS_CHUNK_MATRICES);
		foreach my $matrix (@{$self->{matrices}}) {
			$CDH->w_chunk_data(pack('Z*VV', $matrix->{name}, $matrix->{dwmode}, $matrix->{tcm}));
			$CDH->w_chunk_data(pack('Vf4', $matrix->{scaleU}->get()));
			$CDH->w_chunk_data(pack('Vf4', $matrix->{scaleV}->get()));
			$CDH->w_chunk_data(pack('Vf4', $matrix->{rotate}->get()));
			$CDH->w_chunk_data(pack('Vf4', $matrix->{scrollU}->get()));
			$CDH->w_chunk_data(pack('Vf4', $matrix->{scrollV}->get()));	
		}
		$CDH->w_chunk_close();
	}
}
sub write_blenders {
	my $self = shift;
	my ($CDH, $mode) = @_;	
	print "	blenders\n";
	$CDH->w_chunk_open(SHADERS_CHUNK_BLENDERS);
	my $i = 0;
	foreach my $blender (@{$self->{blenders}}) {
		$CDH->w_chunk_open($i++);
		if ($mode && ($mode eq 'bin')) {
			$CDH->w_chunk_data($$blender);
		} else {
			my $gl_pos = $CDH->offset();
			$blender->{cls} = reverse($blender->{cls});
			$CDH->w_chunk_data(pack('a[8]Z*', $blender->{cls}, $blender->{name}));
			my $delta = 136 + $gl_pos - $CDH->offset();
			$CDH->w_chunk_data(pack("C$delta", 0xED));
			my $pos = $CDH->offset();
			$CDH->w_chunk_data(pack('Z*', $blender->{computer}));
			$delta = 32 + $pos - $CDH->offset();
			$CDH->w_chunk_data(pack("C$delta", 0xED));
			$CDH->w_chunk_data(pack('VvC2', $blender->{ctime}, $blender->{version}, 0xED, 0xED));
			$blender->write($CDH);
		}
		$CDH->w_chunk_close();
	}
	$CDH->w_chunk_close();
}
sub write_names {
	my $self = shift;
	my ($CDH) = @_;	
	print "	names\n";
	$CDH->w_chunk_open(SHADERS_CHUNK_NAMES);
	$CDH->w_chunk_data(pack('V', $#{$self->{names}} + 1));
	foreach my $name (@{$self->{names}}) {
		$CDH->w_chunk_data(pack('Z*', $name));
	}
	$CDH->w_chunk_close();
}
sub export {
	my $self = shift;
	my ($folder, $mode) = @_;
	print "exporting...\n";
	
	mkpath($folder);
	$self->export_constants($folder, $mode);
	$self->export_matrices($folder, $mode);
	$self->export_blenders($folder, $mode);
}
sub export_constants {
	my $self = shift;
	my ($folder, $mode) = @_;	
	print "	constants\n";

	if ($mode && ($mode eq 'bin')) {
		write_file($folder.'\\CONSTANTS.bin', $self->{raw_constants});
	} else {
		mkpath($folder.'\\CONSTANTS');
		foreach my $constant (@{$self->{constants}}) {
			my $fh = IO::File->new($folder.'\\CONSTANTS\\'.$constant->{name}.'.ltx', 'w');
			print $fh "[general]\n";
			print $fh "name = $constant->{name}\n";
			my @R = $constant->{waveforms}[0]->get();
			print $fh "\n[_R]\n";
			print $fh "type = $R[0]\n";
			print $fh "args = $R[1..3]\n";
			my @G = $constant->{waveforms}[1]->get();
			print $fh "\n[_G]\n";
			print $fh "type = $G[0]\n";
			print $fh "args = $G[1..3]\n";
			my @B = $constant->{waveforms}[2]->get();
			print $fh "\n[_B]\n";
			print $fh "type = $B[0]\n";
			print $fh "args = $B[1..3]\n";
			my @A = $constant->{waveforms}[3]->get();
			print $fh "\n[_A]\n";
			print $fh "type = $A[0]\n";
			print $fh "args = $A[1..3]\n";
			$fh->close();
		}
	}
}
sub export_matrices {
	my $self = shift;
	my ($folder, $mode) = @_;	
	print "	matrices\n";

	if ($mode && ($mode eq 'bin')) {
		write_file($folder.'\\MATRICES.bin', $self->{raw_matrices});
	} else {
		mkpath($folder.'\\MATRICES');
		foreach my $matrix (@{$self->{matrices}}) {
			my $fh = IO::File->new($folder.'\\MATRICES\\'.$matrix->{name}.'.ltx', 'w');
			print $fh "[general]\n";
			print $fh "name = $matrix->{name}\n";
			print $fh "dwmode = $matrix->{dwmode}\n";
			print $fh "tcm = $matrix->{tcm}\n";
			my @scaleU = $matrix->{scaleU}->get();
			print $fh "\n[scaleU]\n";
			print $fh "type = $scaleU[0]\n";
			print $fh "args = ".join(',', @scaleU[1..3])."\n";
			my @scaleV = $matrix->{scaleV}->get();
			print $fh "\n[scaleV]\n";
			print $fh "type = $scaleV[0]\n";
			print $fh "args = ".join(',', @scaleV[1..3])."\n";
			my @rotate = $matrix->{rotate}->get();
			print $fh "\n[rotate]\n";
			print $fh "type = $rotate[0]\n";
			print $fh "args = ".join(',', @rotate[1..3])."\n";
			my @scrollU = $matrix->{scrollU}->get();
			print $fh "\n[scrollU]\n";
			print $fh "type = $scrollU[0]\n";
			print $fh "args = ".join(',', @scrollU[1..3])."\n";
			my @scrollV = $matrix->{scrollV}->get();
			print $fh "\n[scrollV]\n";
			print $fh "type = $scrollV[0]\n";
			print $fh "args = ".join(',', @scrollV[1..3])."\n";
			$fh->close();
		}
	}
}
sub export_blenders {
	my $self = shift;
	my ($folder, $mode) = @_;	
	print "	blenders\n";
	my $i = 0;
	mkpath($folder.'\\BLENDERS');
	foreach my $blender (@{$self->{blenders}}) {
		my $name = $self->{names}[$i++];
		my @path = get_path($name);
		mkpath($folder.'\\BLENDERS\\'.$path[0]) if $#path > 0;
		if ($mode && ($mode eq 'bin')) {
			write_file($folder.'\\BLENDERS\\'.$name.'.bin', $blender);
		} else {
			my $ini = IO::File->new($folder.'\\BLENDERS\\'.$name.'.ltx', 'w');
			print $ini "[common]\n";
			print $ini "cls = $blender->{cls}\n";
			print $ini "name = $blender->{name}\n";
			print $ini "computer = $blender->{computer}\n";
			print $ini "ctime = $blender->{ctime}\n";
			print $ini "version = $blender->{version}\n";
			$blender->export($ini);
			$ini->close();
		}
	
	}
}
sub my_import {
	my $self = shift;
	my ($folder, $mode) = @_;
	print "importing...\n";

	$self->import_constants($folder, $mode);
	$self->import_matrices($folder, $mode);
	$self->import_blenders($folder, $mode);
}
sub import_constants {
	my $self = shift;
	my ($folder, $mode) = @_;	
	print "	constants\n";

	if ($mode && ($mode eq 'bin')) {
		$self->{raw_constants} = read_file($folder.'\\CONSTANTS.bin');
	} else {
		my $constants = get_filelist($folder.'\\CONSTANTS\\', 'ltx');
		foreach my $path (@$constants) {
			my $constant = {};
			my $ini = stkutils::ini_file->new($path, 'r') or fail("$path: $!\n");
			$constant->{name} = $ini->value('general', 'name');
			for (my $i = 0; $i < 4; $i++) {
				$constant->{waveforms}[$i] = stkutils::math->create('waveform');
			}
			$constant->{waveforms}[0]->set($ini->value('_R', 'type'), split(/,\s*/, $ini->value('_R', 'args')));
			$constant->{waveforms}[1]->set($ini->value('_G', 'type'), split(/,\s*/, $ini->value('_G', 'args')));
			$constant->{waveforms}[2]->set($ini->value('_B', 'type'), split(/,\s*/, $ini->value('_B', 'args')));
			$constant->{waveforms}[3]->set($ini->value('_A', 'type'), split(/,\s*/, $ini->value('_A', 'args')));
			$ini->close();
			push @{$self->{constants}}, $constant;
		}
	}
}
sub import_matrices {
	my $self = shift;
	my ($folder, $mode) = @_;	
	print "	matrices\n";

	if ($mode && ($mode eq 'bin')) {
		$self->{raw_matrices} = read_file($folder.'\\MATRICES.bin');
	} else {
		my $matrices = get_filelist($folder.'\\MATRICES\\', 'ltx');
		foreach my $path (@$matrices) {
			my $matrix = {};
			my $ini = stkutils::ini_file->new($path, 'r') or fail("$path: $!\n");
			$matrix->{name} = $ini->value('general', 'name');
			$matrix->{dwmode} = $ini->value('general', 'dwmode');
			$matrix->{tcm} = $ini->value('general', 'tcm');
			$matrix->{scaleU} = stkutils::math->create('waveform');
			$matrix->{scaleU}->set($ini->value('scaleU', 'type'), split(/,\s*/, $ini->value('scaleU', 'args')));
			$matrix->{scaleV} = stkutils::math->create('waveform');
			$matrix->{scaleV}->set($ini->value('scaleV', 'type'), split(/,\s*/, $ini->value('scaleV', 'args')));
			$matrix->{rotate} = stkutils::math->create('waveform');
			$matrix->{rotate}->set($ini->value('rotate', 'type'), split(/,\s*/, $ini->value('rotate', 'args')));
			$matrix->{scrollU} = stkutils::math->create('waveform');
			$matrix->{scrollU}->set($ini->value('scrollU', 'type'), split(/,\s*/, $ini->value('scrollU', 'args')));
			$matrix->{scrollV} = stkutils::math->create('waveform');
			$matrix->{scrollV}->set($ini->value('scrollV', 'type'), split(/,\s*/, $ini->value('scrollV', 'args')));
			$ini->close();
			push @{$self->{matrices}}, $matrix;
		}
	}
}
sub import_blenders {
	my $self = shift;
	my ($folder, $mode) = @_;	
	print "	blenders\n";

	if ($mode && ($mode eq 'bin')) {
		my $blenders = get_filelist($folder.'\\BLENDERS\\', 'bin');
		foreach my $path (@$blenders) {
			push @{$self->{blenders}}, read_file($path);
			push @{$self->{names}}, prepare_path($path);
		}
	} else {
		my $blenders = get_filelist($folder.'\\BLENDERS\\', 'ltx');
		foreach my $path (@$blenders) {
			my $blender = {};
			my $ini = stkutils::ini_file->new($path, 'r') or fail("$path: $!\n");
			$blender->{cls} = $ini->value('common', 'cls');
			$blender->{name} = $ini->value('common', 'name');
			$blender->{computer} = $ini->value('common', 'computer');
			$blender->{ctime} = $ini->value('common', 'ctime');
			$blender->{version} = $ini->value('common', 'version');
#			print "$blender->{name}: $blender->{cls}\n";
			SWITCH: {
				(($blender->{cls} eq 'LmBmmD  ') 																								#CBlender_BmmD
				|| ($blender->{cls} eq 'BmmDold ')) && do {bless ($blender, 'CBlender_BmmD'); $blender->import($ini); last SWITCH;};
				(($blender->{cls} eq 'MODELEbB') 																							#CBlender_Model_EbB
				|| ($blender->{cls} eq 'LmEbB   ')) && do {bless ($blender, 'CBlender_EbB'); $blender->import($ini); last SWITCH;};			#CBlender_LmEbB
				($blender->{cls} eq 'D_STILL ') && do {bless ($blender, 'CBlender_Detail_Still'); $blender->import($ini); last SWITCH;};
				($blender->{cls} eq 'D_TREE  ') && do {bless ($blender, 'CBlender_Tree'); $blender->import($ini); last SWITCH;};
				($blender->{cls} eq 'LM_AREF ') && do {bless ($blender, 'CBlender_deffer_aref'); $blender->import($ini); last SWITCH;};
				($blender->{cls} eq 'V_AREF  ') && do {bless ($blender, 'CBlender_Vertex_aref'); $blender->import($ini); last SWITCH;};
				($blender->{cls} eq 'MODEL   ') && do {bless ($blender, 'CBlender_deffer_model'); $blender->import($ini); last SWITCH;};
				(($blender->{cls} eq 'E_SEL   ') 																								#CBlender_Editor_Selection
				|| ($blender->{cls} eq 'E_WIRE  ')) && do {bless ($blender, 'CBlender_Editor'); $blender->import($ini); last SWITCH;};		#CBlender_Editor_Wire
				($blender->{cls} eq 'PARTICLE') && do {bless ($blender, 'CBlender_Particle'); $blender->import($ini); last SWITCH;};
				($blender->{cls} eq 'S_SET   ') && do {bless ($blender, 'CBlender_Screen_SET'); $blender->import($ini); last SWITCH;};
				(($blender->{cls} eq 'BLUR    ')																								#CBlender_Blur, 		R1 only
				|| ($blender->{cls} eq 'LM      ') 																								#CBlender_default,		R1 only
				|| ($blender->{cls} eq 'SH_WORLD')																							#CBlender_ShWorld, 		R1 only
				|| ($blender->{cls} eq 'S_GRAY  ')																							#CBlender_Screen_GRAY, 	R1 only
				|| ($blender->{cls} eq 'V       ')) && do {bless ($blender, 'CBlender_Tesselation'); $blender->import($ini); last SWITCH;};					#CBlender_Vertex, 		R1 only
				warn('unsupported cls '.$blender->{cls}); next;
			}
			push @{$self->{blenders}}, $blender;
			push @{$self->{names}}, prepare_path($path);
		}
	}
}
sub prepare_path {
	my $path = shift;
	$path =~ s/\//\\/g;
	my @temp = split /\\+/, $path;
	my $l = $#temp;
	my $i = 0;
	foreach (@temp) {
		$i++;
		last if ($_ eq 'BLENDERS');
	}
	return substr(join('\\', @temp[$i..$l]), 0, -4);
}
#######################################################################
package IBlender;
use strict;

use constant xrPID_MARKER => 0;
use constant xrPID_MATRIX => 1;
use constant xrPID_CONSTANT => 2;
use constant xrPID_TEXTURE => 3;
use constant xrPID_INTEGER => 4;
use constant xrPID_BOOL => 6;
use constant xrPID_TOKEN => 7;

sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;
	return $self;
}
sub read {
	my $self = shift;
	my $packet = shift;
	$self->{properties}{M_General} = $self->load_value($packet, xrPID_MARKER);
	$self->{properties}{oPriority} = $self->load_value($packet, xrPID_INTEGER);
	$self->{properties}{oStrictSorting} = $self->load_value($packet, xrPID_BOOL);
	$self->{properties}{M_Base_Texture} = $self->load_value($packet, xrPID_MARKER);
	$self->{properties}{oT_Name} = $self->load_value($packet, xrPID_TEXTURE);
	$self->{properties}{oT_xform} = $self->load_value($packet, xrPID_MATRIX);
}
sub write {
	my $self = shift;
	my $CDH = shift;
	$self->save_value($CDH, 'M_General', xrPID_MARKER);
	$self->save_value($CDH, 'oPriority', xrPID_INTEGER);
	$self->save_value($CDH, 'oStrictSorting', xrPID_BOOL);
	$self->save_value($CDH, 'M_Base_Texture', xrPID_MARKER);
	$self->save_value($CDH, 'oT_Name', xrPID_TEXTURE);
	$self->save_value($CDH, 'oT_xform', xrPID_MATRIX);
}
sub import {
	my $self = shift;
	my $ini = shift;
	
	$self->{properties}{M_General}->{name} = 'General';
	$self->{properties}{M_General}->{value} = undef;
	$self->{properties}{oPriority}->{name} = 'Priority';
	@{$self->{properties}{oPriority}->{value}} = split /,\s*/, $ini->value($self->{properties}{M_General}->{name}, $self->{properties}{oPriority}->{name} );
	$self->{properties}{oStrictSorting}->{name} = 'Strict sorting';
	$self->{properties}{oStrictSorting}->{value} = $ini->value($self->{properties}{M_General}->{name}, $self->{properties}{oStrictSorting}->{name});
	$self->{properties}{M_Base_Texture}->{name} = 'Base Texture';
	$self->{properties}{M_Base_Texture}->{value} = undef;
	$self->{properties}{oT_Name}->{name} = 'Name';
	$self->{properties}{oT_Name}->{value} = $ini->value($self->{properties}{M_Base_Texture}->{name}, $self->{properties}{oT_Name}->{name});
	$self->{properties}{oT_xform}->{name} = 'Transform';
	$self->{properties}{oT_xform}->{value} = $ini->value($self->{properties}{M_Base_Texture}->{name}, $self->{properties}{oT_xform}->{name});
}
sub export {
	my $self = shift;
	my $ini = shift;
	
	print $ini "\n[$self->{properties}{M_General}->{name}]\n";
	print $ini "$self->{properties}{oPriority}->{name} = ".join(',', @{$self->{properties}{oPriority}->{value}})."\n";
	print $ini "$self->{properties}{oStrictSorting}->{name} = $self->{properties}{oStrictSorting}->{value}\n";
	print $ini "\n[$self->{properties}{M_Base_Texture}->{name}]\n";
	print $ini "$self->{properties}{oT_Name}->{name} = $self->{properties}{oT_Name}->{value}\n";
	print $ini "$self->{properties}{oT_xform}->{name} = $self->{properties}{oT_xform}->{value}\n";
}
sub load_value {
	my $self = shift;
	my $packet = shift;
	my ($type) = @_;
	my ($marker) = $packet->unpack('V');
	my %hash;
	my @val;
	SWITCH: {
		$marker == xrPID_MARKER && $marker == $type && do {($hash{name}) = $packet->unpack('Z*'); $hash{value} = undef; last SWITCH;};
		(($marker == xrPID_MATRIX) || ($marker == xrPID_TEXTURE) || ($marker == xrPID_CONSTANT)) && $marker == $type && do {($hash{name}, $hash{value}) = $packet->unpack('Z*Z*'); $packet->pos($packet->pos() + 64 - length($hash{value}) - 1); last SWITCH;};
		$marker == xrPID_INTEGER && $marker == $type && do {($hash{name}, @val) = $packet->unpack('Z*V3'); $hash{value} = \@val; last SWITCH;};
		$marker == xrPID_BOOL && $marker == $type && do {($hash{name}, $hash{value}) = $packet->unpack('Z*V'); last SWITCH;};
		$marker == xrPID_TOKEN && $marker == $type && do {($hash{name}, @val) = $packet->unpack('Z*VV'); $hash{value} = \@val; last SWITCH;};
	}
	return \%hash;
}
sub save_value {
	my $self = shift;
	my $CDH = shift;
	my ($prop, $type) = @_;
	$CDH->w_chunk_data(pack('VZ*', $type, $self->{properties}{$prop}->{name}));
	SWITCH: {
		(($type == xrPID_MATRIX) || ($type == xrPID_TEXTURE) || ($type == xrPID_CONSTANT)) && do {
			my $pos = $CDH->offset();
			$CDH->w_chunk_data(pack('Z*', $self->{properties}{$prop}->{value}));
			my $delta = 64 + $pos - $CDH->offset();
			$CDH->w_chunk_data(pack("C$delta", 0xED));
			last SWITCH;};
		$type == xrPID_INTEGER && do {$CDH->w_chunk_data(pack('V3', @{$self->{properties}{$prop}->{value}})); last SWITCH;};
		$type == xrPID_BOOL && do {$CDH->w_chunk_data(pack('V', $self->{properties}{$prop}->{value})); last SWITCH;};
		$type == xrPID_TOKEN && do {$CDH->w_chunk_data(pack('V2', @{$self->{properties}{$prop}->{value}})); last SWITCH;};
	}
}
sub load_set {
	my $self = shift;
	my ($packet) = @_;
	
	my $set = {};
	($set->{ID}, $set->{name}) = $packet->unpack('VZ*');
	$packet->pos($packet->pos() + 64 - length($set->{name}) - 1);
	return $set;
}
sub save_set {
	my $self = shift;
	my ($set, $CDH) = @_;
	
	my $pos = $CDH->offset();
	$CDH->w_chunk_data(pack('VZ*', $set->{ID}, $set->{name}));
	my $delta = 68 + $pos - $CDH->offset();
	$CDH->w_chunk_data(pack("C$delta", 0xED));
}
#######################################################################
package CBlender_BmmD;
use strict;
use base 'IBlender';

use constant xrPID_MARKER => 0;
use constant xrPID_MATRIX => 1;
use constant xrPID_CONSTANT => 2;
use constant xrPID_TEXTURE => 3;
use constant xrPID_INTEGER => 4;
use constant xrPID_BOOL => 6;
use constant xrPID_TOKEN => 7;

sub new {
	my $class = shift;
	my $self = {};
	$self->{properties} = {};
	bless $self, $class;
	return $self;
}
sub read {
	my $self = shift;
	my $packet = shift;
	$self->IBlender::read($packet);
	
	$self->{properties}{M_CBlender_BmmD} = $self->load_value($packet, xrPID_MARKER);
	$self->{properties}{oT2_Name} = $self->load_value($packet, xrPID_TEXTURE);
	$self->{properties}{oT2_xform} = $self->load_value($packet, xrPID_MATRIX);
	if ($self->{version} >= 3) {
		$self->{properties}{oR_Name} = $self->load_value($packet, xrPID_TEXTURE);
		$self->{properties}{oG_Name} = $self->load_value($packet, xrPID_TEXTURE);
		$self->{properties}{oB_Name} = $self->load_value($packet, xrPID_TEXTURE);
		$self->{properties}{oA_Name} = $self->load_value($packet, xrPID_TEXTURE);	
	}
}
sub write {
	my $self = shift;
	my $CDH = shift;
	
	$self->IBlender::write($CDH);
	$self->save_value($CDH, 'M_CBlender_BmmD', xrPID_MARKER);
	$self->save_value($CDH, 'oT2_Name', xrPID_TEXTURE);
	$self->save_value($CDH, 'oT2_xform', xrPID_MATRIX);
	if ($self->{version} >= 3) {
		$self->save_value($CDH, 'oR_Name', xrPID_TEXTURE);
		$self->save_value($CDH, 'oG_Name', xrPID_TEXTURE);
		$self->save_value($CDH, 'oB_Name', xrPID_TEXTURE);
		$self->save_value($CDH, 'oA_Name', xrPID_TEXTURE);	
	}
}
sub import {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::import($ini);
	$self->{properties}{M_CBlender_BmmD}->{name} = $ini->value('properties', 'class');
	$self->{properties}{M_CBlender_BmmD}->{value} = undef;
	$self->{properties}{oT2_Name}->{name} = 'Name';
	$self->{properties}{oT2_Name}->{value} = $ini->value('properties', $self->{properties}{oT2_Name}->{name});
	$self->{properties}{oT2_xform}->{name} = 'Transform';
	$self->{properties}{oT2_xform}->{value} = $ini->value('properties', $self->{properties}{oT2_xform}->{name});	
	if ($self->{version} >= 3) {
		$self->{properties}{oR_Name}->{name} = 'R2-R';
		$self->{properties}{oR_Name}->{value} = $ini->value('properties', $self->{properties}{oR_Name}->{name});
		$self->{properties}{oG_Name}->{name} = 'R2-G';
		$self->{properties}{oG_Name}->{value} = $ini->value('properties', $self->{properties}{oG_Name}->{name});	
		$self->{properties}{oB_Name}->{name} = 'R2-B';
		$self->{properties}{oB_Name}->{value} = $ini->value('properties', $self->{properties}{oB_Name}->{name});
		$self->{properties}{oA_Name}->{name} = 'R2-A';
		$self->{properties}{oA_Name}->{value} = $ini->value('properties', $self->{properties}{oA_Name}->{name});		
	}
}
sub export {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::export($ini);
	print $ini "\n[properties]\n";
	print $ini "class = $self->{properties}{M_CBlender_BmmD}->{name}\n";
	print $ini "$self->{properties}{oT2_Name}->{name} = $self->{properties}{oT2_Name}->{value}\n";
	print $ini "$self->{properties}{oT2_xform}->{name} = $self->{properties}{oT2_xform}->{value}\n";
	if ($self->{version} >= 3) {
		print $ini "$self->{properties}{oR_Name}->{name} = $self->{properties}{oR_Name}->{value}\n";
		print $ini "$self->{properties}{oG_Name}->{name} = $self->{properties}{oG_Name}->{value}\n";
		print $ini "$self->{properties}{oB_Name}->{name} = $self->{properties}{oB_Name}->{value}\n";
		print $ini "$self->{properties}{oA_Name}->{name} = $self->{properties}{oA_Name}->{value}\n";
	}
}
#######################################################################
package CBlender_EbB;
use strict;
use base 'IBlender';

use constant xrPID_MARKER => 0;
use constant xrPID_MATRIX => 1;
use constant xrPID_CONSTANT => 2;
use constant xrPID_TEXTURE => 3;
use constant xrPID_INTEGER => 4;
use constant xrPID_BOOL => 6;
use constant xrPID_TOKEN => 7;

sub new {
	my $class = shift;
	my $self = {};
	$self->{properties} = {};
	bless $self, $class;
	return $self;
}
sub read {
	my $self = shift;
	my $packet = shift;
	$self->IBlender::read($packet);
	
	$self->{properties}{M_CBlender_EbB} = $self->load_value($packet, xrPID_MARKER);
	$self->{properties}{oT2_Name} = $self->load_value($packet, xrPID_TEXTURE);
	$self->{properties}{oT2_xform} = $self->load_value($packet, xrPID_MATRIX);
	if ($self->{version} >= 1) {
		$self->{properties}{oBlend} = $self->load_value($packet, xrPID_BOOL);
	}
}
sub write {
	my $self = shift;
	my $CDH = shift;
	
	$self->IBlender::write($CDH);
	$self->save_value($CDH, 'M_CBlender_EbB', xrPID_MARKER);
	$self->save_value($CDH, 'oT2_Name', xrPID_TEXTURE);
	$self->save_value($CDH, 'oT2_xform', xrPID_MATRIX);
	if ($self->{version} >= 1) {
		$self->save_value($CDH, 'oBlend', xrPID_BOOL);
	}
}
sub import {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::import($ini);
	$self->{properties}{M_CBlender_EbB}->{name} = $ini->value('properties', 'class');
	$self->{properties}{M_CBlender_EbB}->{value} = undef;
	$self->{properties}{oT2_Name}->{name} = 'Name';
	$self->{properties}{oT2_Name}->{value} = $ini->value('properties', $self->{properties}{oT2_Name}->{name});
	$self->{properties}{oT2_xform}->{name} = 'Transform';
	$self->{properties}{oT2_xform}->{value} = $ini->value('properties', $self->{properties}{oT2_xform}->{name});	
	if ($self->{version} >= 1) {
		$self->{properties}{oBlend}->{name} = 'Alpha-Blend';
		$self->{properties}{oBlend}->{value} = $ini->value('properties', $self->{properties}{oBlend}->{name});	
	}
}
sub export {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::export($ini);
	print $ini "\n[properties]\n";
	print $ini "class = $self->{properties}{M_CBlender_EbB}->{name}\n";
	print $ini "$self->{properties}{oT2_Name}->{name} = $self->{properties}{oT2_Name}->{value}\n";
	print $ini "$self->{properties}{oT2_xform}->{name} = $self->{properties}{oT2_xform}->{value}\n";
	if ($self->{version} >= 1) {
		print $ini "$self->{properties}{oBlend}->{name} = $self->{properties}{oBlend}->{value}\n";
	}
}
#######################################################################
package CBlender_Detail_Still;
use strict;
use base 'IBlender';

use constant xrPID_MARKER => 0;
use constant xrPID_MATRIX => 1;
use constant xrPID_CONSTANT => 2;
use constant xrPID_TEXTURE => 3;
use constant xrPID_INTEGER => 4;
use constant xrPID_BOOL => 6;
use constant xrPID_TOKEN => 7;

sub new {
	my $class = shift;
	my $self = {};
	$self->{properties} = {};
	bless $self, $class;
	return $self;
}
sub read {
	my $self = shift;
	my $packet = shift;
	$self->IBlender::read($packet);

	$self->{properties}{oBlend} = $self->load_value($packet, xrPID_BOOL);
}
sub write {
	my $self = shift;
	my $CDH = shift;
	
	$self->IBlender::write($CDH);
	$self->save_value($CDH, 'oBlend', xrPID_BOOL);
}
sub import {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::import($ini);
	$self->{properties}{oBlend}->{name} = 'Alpha-blend';
	$self->{properties}{oBlend}->{value} = $ini->value('properties', $self->{properties}{oBlend}->{name});	
}
sub export {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::export($ini);
	print $ini "\n[properties]\n";
	print $ini "$self->{properties}{oBlend}->{name} = $self->{properties}{oBlend}->{value}\n";
}
#######################################################################
package CBlender_Tree;
use strict;
use base 'IBlender';

use constant xrPID_MARKER => 0;
use constant xrPID_MATRIX => 1;
use constant xrPID_CONSTANT => 2;
use constant xrPID_TEXTURE => 3;
use constant xrPID_INTEGER => 4;
use constant xrPID_BOOL => 6;
use constant xrPID_TOKEN => 7;

sub new {
	my $class = shift;
	my $self = {};
	$self->{properties} = {};
	bless $self, $class;
	return $self;
}
sub read {
	my $self = shift;
	my $packet = shift;
	$self->IBlender::read($packet);

	$self->{properties}{oBlend} = $self->load_value($packet, xrPID_BOOL);
	if ($self->{version} >= 1) {
		$self->{properties}{oNotAnTree} = $self->load_value($packet, xrPID_BOOL);
	}
}
sub write {
	my $self = shift;
	my $CDH = shift;
	
	$self->IBlender::write($CDH);
	$self->save_value($CDH, 'oBlend', xrPID_BOOL);
	if ($self->{version} >= 1) {
		$self->save_value($CDH, 'oNotAnTree', xrPID_BOOL);
	}
}
sub import {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::import($ini);
	$self->{properties}{oBlend}->{name} = 'Alpha-blend';
	$self->{properties}{oBlend}->{value} = $ini->value('properties', $self->{properties}{oBlend}->{name});
	if ($self->{version} >= 1) {
		$self->{properties}{oNotAnTree}->{name} = 'Object LOD';
		$self->{properties}{oNotAnTree}->{value} = $ini->value('properties',  $self->{properties}{oNotAnTree}->{name});
	}
}	
sub export {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::export($ini);
	print $ini "\n[properties]\n";
	print $ini "$self->{properties}{oBlend}->{name} = $self->{properties}{oBlend}->{value}\n";
	if ($self->{version} >= 1) {
		print $ini "$self->{properties}{oNotAnTree}->{name} = $self->{properties}{oNotAnTree}->{value}\n";
	}
}
#######################################################################
package CBlender_deffer_aref;
use strict;
use base 'IBlender';

use constant xrPID_MARKER => 0;
use constant xrPID_MATRIX => 1;
use constant xrPID_CONSTANT => 2;
use constant xrPID_TEXTURE => 3;
use constant xrPID_INTEGER => 4;
use constant xrPID_BOOL => 6;
use constant xrPID_TOKEN => 7;

sub new {
	my $class = shift;
	my $self = {};
	$self->{properties} = {};
	bless $self, $class;
	return $self;
}
sub read {
	my $self = shift;
	my $packet = shift;
	$self->IBlender::read($packet);

	if ($self->{version} == 1) {
		$self->{properties}{oAREF} = $self->load_value($packet, xrPID_INTEGER);
		$self->{properties}{oBlend} = $self->load_value($packet, xrPID_BOOL);
	}
}
sub write {
	my $self = shift;
	my $CDH = shift;
	
	$self->IBlender::write($CDH);
	if ($self->{version} == 1) {
		$self->save_value($CDH, 'oAREF', xrPID_INTEGER);
		$self->save_value($CDH, 'oBlend', xrPID_BOOL);
	}
}
sub import {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::import($ini);
	if ($self->{version} == 1) {
		$self->{properties}{oAREF}->{name} = 'Alpha ref';
		@{$self->{properties}{oAREF}->{value}} = split /,\s*/, $ini->value('properties',  $self->{properties}{oAREF}->{name});
		$self->{properties}{oBlend}->{name} = 'Alpha-blend';
		$self->{properties}{oBlend}->{value} = $ini->value('properties', $self->{properties}{oBlend}->{name});
	}
}	
sub export {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::export($ini);
	print $ini "\n[properties]\n";
	if ($self->{version} == 1) {
		print $ini "$self->{properties}{oAREF}->{name} = ".join(',', @{$self->{properties}{oAREF}->{value}})."\n";
		print $ini "$self->{properties}{oBlend}->{name} = $self->{properties}{oBlend}->{value}\n";
	}
}
#######################################################################
package CBlender_Vertex_aref;
use strict;
use base 'IBlender';

use constant xrPID_MARKER => 0;
use constant xrPID_MATRIX => 1;
use constant xrPID_CONSTANT => 2;
use constant xrPID_TEXTURE => 3;
use constant xrPID_INTEGER => 4;
use constant xrPID_BOOL => 6;
use constant xrPID_TOKEN => 7;

sub new {
	my $class = shift;
	my $self = {};
	$self->{properties} = {};
	bless $self, $class;
	return $self;
}
sub read {
	my $self = shift;
	my $packet = shift;
	$self->IBlender::read($packet);

	$self->{properties}{oAREF} = $self->load_value($packet, xrPID_INTEGER);
	if ($self->{version} > 0) {
		$self->{properties}{oBlend} = $self->load_value($packet, xrPID_BOOL);
	}
}
sub write {
	my $self = shift;
	my $CDH = shift;
	
	$self->IBlender::write($CDH);
	$self->save_value($CDH, 'oAREF', xrPID_INTEGER);
	if ($self->{version} > 0) {
		$self->save_value($CDH, 'oBlend', xrPID_BOOL);
	}
}
sub import {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::import($ini);
	$self->{properties}{oAREF}->{name} = 'Alpha ref';
	@{$self->{properties}{oAREF}->{value}} = split /,\s*/, $ini->value('properties',  $self->{properties}{oAREF}->{name});
	if ($self->{version} > 0) {
		$self->{properties}{oBlend}->{name} = 'Alpha-blend';
		$self->{properties}{oBlend}->{value} = $ini->value('properties', $self->{properties}{oBlend}->{name});
	}
}	
sub export {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::export($ini);
	print $ini "\n[properties]\n";
	
	print $ini "$self->{properties}{oAREF}->{name} = ".join(',', @{$self->{properties}{oAREF}->{value}})."\n";
	if ($self->{version} > 0) {
		print $ini "$self->{properties}{oBlend}->{name} = $self->{properties}{oBlend}->{value}\n";
	}
}
#######################################################################
package CBlender_Tesselation;
use strict;
use base 'IBlender';

use constant xrPID_MARKER => 0;
use constant xrPID_MATRIX => 1;
use constant xrPID_CONSTANT => 2;
use constant xrPID_TEXTURE => 3;
use constant xrPID_INTEGER => 4;
use constant xrPID_BOOL => 6;
use constant xrPID_TOKEN => 7;

sub new {
	my $class = shift;
	my $self = {};
	$self->{properties} = {};
	bless $self, $class;
	return $self;
}
sub read {
	my $self = shift;
	my $packet = shift;
	$self->IBlender::read($packet);

	if ($self->{version} > 0) {
		$self->{properties}{oTess} = $self->load_value($packet, xrPID_TOKEN);
		for (my $i = 0; $i < $self->{properties}{oTess}->{value}->[1]; $i++) {
			push @{$self->{properties}{SETS}}, $self->load_set($packet);
		}
	}
}
sub write {
	my $self = shift;
	my $CDH = shift;
	
	$self->IBlender::write($CDH);
	if ($self->{version} > 0) {
		$self->save_value($CDH, 'oTess', xrPID_TOKEN);
		foreach my $set (@{$self->{properties}{SETS}}) {
			$self->save_set($set, $CDH);
		}
	}
}
sub import {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::import($ini);
	if ($self->{version} > 0) {
		$self->{properties}{oTess}->{name} = 'Tessellation';
		@{$self->{properties}{oTess}->{value}} = split /,\s*/, $ini->value('properties', $self->{properties}{oTess}->{name});
		for (my $i = 0; $i < $self->{properties}{oTess}->{value}->[1]; $i++) {
			my $set = {};
			$set->{ID} = $i;
			$set->{name} = $ini->value('sets', $set->{ID});
			push @{$self->{properties}{SETS}}, $set;
		}
	}
}	
sub export {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::export($ini);
	print $ini "\n[properties]\n";
	
	if ($self->{version} > 0) {
		print $ini "$self->{properties}{oTess}->{name} = ".join(',', @{$self->{properties}{oTess}->{value}})."\n";
		print $ini "\n[sets]\n";
		foreach my $set (@{$self->{properties}{SETS}}) {
			print $ini "$set->{ID} = $set->{name}\n";
		}
	}
}
#######################################################################
package CBlender_deffer_model;
use strict;
use base 'IBlender';

use constant xrPID_MARKER => 0;
use constant xrPID_MATRIX => 1;
use constant xrPID_CONSTANT => 2;
use constant xrPID_TEXTURE => 3;
use constant xrPID_INTEGER => 4;
use constant xrPID_BOOL => 6;
use constant xrPID_TOKEN => 7;

sub new {
	my $class = shift;
	my $self = {};
	$self->{properties} = {};
	bless $self, $class;
	return $self;
}
sub read {
	my $self = shift;
	my $packet = shift;
	$self->IBlender::read($packet);

	if ($self->{version} >= 1) {
		$self->{properties}{oBlend} = $self->load_value($packet, xrPID_BOOL);
		$self->{properties}{oAREF} = $self->load_value($packet, xrPID_INTEGER);
		if ($self->{version} >= 2) {
			$self->{properties}{oTess} = $self->load_value($packet, xrPID_TOKEN);
			for (my $i = 0; $i < $self->{properties}{oTess}->{value}->[1]; $i++) {
				push @{$self->{properties}{SETS}}, $self->load_set($packet);
			}	
		}
	}
}
sub write {
	my $self = shift;
	my $CDH = shift;
	
	$self->IBlender::write($CDH);
	if ($self->{version} >= 1) {
		$self->save_value($CDH, 'oBlend', xrPID_BOOL);
		$self->save_value($CDH, 'oAREF', xrPID_INTEGER);
		if ($self->{version} >= 2) {
			$self->save_value($CDH, 'oTess', xrPID_TOKEN);
			foreach my $set (@{$self->{properties}{SETS}}) {
				$self->save_set($set, $CDH);
			}
		}
	}
}
sub import {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::import($ini);
	if ($self->{version} >= 1) {
		$self->{properties}{oAREF}->{name} = 'Alpha ref';
		@{$self->{properties}{oAREF}->{value}} = split /,\s*/, $ini->value('properties',  $self->{properties}{oAREF}->{name});
		$self->{properties}{oBlend}->{name} = 'Use alpha-channel';
		$self->{properties}{oBlend}->{value} = $ini->value('properties', $self->{properties}{oBlend}->{name});
		if ($self->{version} >= 2) {
			$self->{properties}{oTess}->{name} = 'Tessellation';
			@{$self->{properties}{oTess}->{value}} = split /,\s*/, $ini->value('properties', $self->{properties}{oTess}->{name});
			for (my $i = 0; $i < $self->{properties}{oTess}->{value}->[1]; $i++) {
				my $set = {};
				$set->{ID} = $i;
				$set->{name} = $ini->value('sets', $set->{ID});
				push @{$self->{properties}{SETS}}, $set;
			}
		}
	}
}	
sub export {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::export($ini);
	print $ini "\n[properties]\n";
	if ($self->{version} >= 1) {
		print $ini "$self->{properties}{oAREF}->{name} = ".join(',', @{$self->{properties}{oAREF}->{value}})."\n";
		print $ini "$self->{properties}{oBlend}->{name} = $self->{properties}{oBlend}->{value}\n";
		if ($self->{version} >= 2) {
			print $ini "$self->{properties}{oTess}->{name} = ".join(',', @{$self->{properties}{oTess}->{value}})."\n";
			print $ini "\n[sets]\n";
			foreach my $set (@{$self->{properties}{SETS}}) {
				print $ini "$set->{ID} = $set->{name}\n";
			}
		}
	}
}
#######################################################################
package CBlender_Editor;
use strict;
use base 'IBlender';

use constant xrPID_MARKER => 0;
use constant xrPID_MATRIX => 1;
use constant xrPID_CONSTANT => 2;
use constant xrPID_TEXTURE => 3;
use constant xrPID_INTEGER => 4;
use constant xrPID_BOOL => 6;
use constant xrPID_TOKEN => 7;

sub new {
	my $class = shift;
	my $self = {};
	$self->{properties} = {};
	bless $self, $class;
	return $self;
}
sub read {
	my $self = shift;
	my $packet = shift;
	$self->IBlender::read($packet);

	$self->{properties}{oT_Factor} = $self->load_value($packet, xrPID_CONSTANT);
}
sub write {
	my $self = shift;
	my $CDH = shift;
	
	$self->IBlender::write($CDH);
	$self->save_value($CDH, 'oT_Factor', xrPID_CONSTANT);
}
sub import {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::import($ini);
	$self->{properties}{oT_Factor}->{name} = 'TFactor';
	$self->{properties}{oT_Factor}->{value} = $ini->value('properties', $self->{properties}{oT_Factor}->{name});
}	
sub export {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::export($ini);
	print $ini "\n[properties]\n";
	print $ini "$self->{properties}{oT_Factor}->{name} = $self->{properties}{oT_Factor}->{value}\n";
}
#######################################################################
package CBlender_Particle;
use strict;
use base 'IBlender';

use constant xrPID_MARKER => 0;
use constant xrPID_MATRIX => 1;
use constant xrPID_CONSTANT => 2;
use constant xrPID_TEXTURE => 3;
use constant xrPID_INTEGER => 4;
use constant xrPID_BOOL => 6;
use constant xrPID_TOKEN => 7;

sub new {
	my $class = shift;
	my $self = {};
	$self->{properties} = {};
	bless $self, $class;
	return $self;
}
sub read {
	my $self = shift;
	my $packet = shift;
	$self->IBlender::read($packet);

	$self->{properties}{oBlend} = $self->load_value($packet, xrPID_TOKEN);
	for (my $i = 0; $i < $self->{properties}{oBlend}->{value}->[1]; $i++) {
		push @{$self->{properties}{SETS}}, $self->load_set($packet);
	}
	$self->{properties}{oClamp} = $self->load_value($packet, xrPID_BOOL);
	$self->{properties}{oAREF} = $self->load_value($packet, xrPID_INTEGER);
}
sub write {
	my $self = shift;
	my $CDH = shift;
	
	$self->IBlender::write($CDH);
	$self->save_value($CDH, 'oBlend', xrPID_TOKEN);
	foreach my $set (@{$self->{properties}{SETS}}) {
		$self->save_set($set, $CDH);
	}
	$self->save_value($CDH, 'oClamp', xrPID_BOOL);
	$self->save_value($CDH, 'oAREF', xrPID_INTEGER);
}
sub import {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::import($ini);
	$self->{properties}{oBlend}->{name} = 'Blending';
	@{$self->{properties}{oBlend}->{value}} = split /,\s*/, $ini->value('properties', $self->{properties}{oBlend}->{name});
	$self->{properties}{oClamp}->{name} = 'Texture clamp';
	$self->{properties}{oClamp}->{value} = $ini->value('properties', $self->{properties}{oClamp}->{name});
	$self->{properties}{oAREF}->{name} = 'Alpha ref';
	@{$self->{properties}{oAREF}->{value}} = split /,\s*/, $ini->value('properties', $self->{properties}{oAREF}->{name});
	for (my $i = 0; $i < $self->{properties}{oBlend}->{value}->[1]; $i++) {
		my $set = {};
		$set->{ID} = $i;
		$set->{name} = $ini->value('sets', $set->{ID});
		push @{$self->{properties}{SETS}}, $set;
	}
}	
sub export {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::export($ini);
	print $ini "\n[properties]\n";
	print $ini "$self->{properties}{oBlend}->{name} = ".join(',', @{$self->{properties}{oBlend}->{value}})."\n";
	print $ini "$self->{properties}{oClamp}->{name} = $self->{properties}{oClamp}->{value}\n";
	print $ini "$self->{properties}{oAREF}->{name} = ".join(',', @{$self->{properties}{oAREF}->{value}})."\n";
	print $ini "\n[sets]\n";
	foreach my $set (@{$self->{properties}{SETS}}) {
		print $ini "$set->{ID} = $set->{name}\n";
	}
}
#######################################################################
package CBlender_Screen_SET;
use strict;
use base 'IBlender';

use constant xrPID_MARKER => 0;
use constant xrPID_MATRIX => 1;
use constant xrPID_CONSTANT => 2;
use constant xrPID_TEXTURE => 3;
use constant xrPID_INTEGER => 4;
use constant xrPID_BOOL => 6;
use constant xrPID_TOKEN => 7;

sub new {
	my $class = shift;
	my $self = {};
	$self->{properties} = {};
	bless $self, $class;
	return $self;
}
sub read {
	my $self = shift;
	my $packet = shift;
	$self->IBlender::read($packet);

	$self->{properties}{oBlend} = $self->load_value($packet, xrPID_TOKEN);
	for (my $i = 0; $i < $self->{properties}{oBlend}->{value}->[1]; $i++) {
		push @{$self->{properties}{SETS}}, $self->load_set($packet);
	}
	$self->{properties}{oClamp} = $self->load_value($packet, xrPID_BOOL) if ($self->{version} != 2);
	$self->{properties}{oAREF} = $self->load_value($packet, xrPID_INTEGER);
	$self->{properties}{oZTest} = $self->load_value($packet, xrPID_BOOL);
	$self->{properties}{oZWrite} = $self->load_value($packet, xrPID_BOOL);
	$self->{properties}{oLighting} = $self->load_value($packet, xrPID_BOOL);
	$self->{properties}{oFog} = $self->load_value($packet, xrPID_BOOL);
}
sub write {
	my $self = shift;
	my $CDH = shift;
	
	$self->IBlender::write($CDH);
	$self->save_value($CDH, 'oBlend', xrPID_TOKEN);
	foreach my $set (@{$self->{properties}{SETS}}) {
		$self->save_set($set, $CDH);
	}
	$self->save_value($CDH, 'oClamp', xrPID_BOOL);
	$self->save_value($CDH, 'oAREF', xrPID_INTEGER);
	$self->save_value($CDH, 'oZTest', xrPID_BOOL);
	$self->save_value($CDH, 'oZWrite', xrPID_BOOL);
	$self->save_value($CDH, 'oLighting', xrPID_BOOL);
	$self->save_value($CDH, 'oFog', xrPID_BOOL);
}
sub import {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::import($ini);
	$self->{properties}{oBlend}->{name} = 'Blending';
	@{$self->{properties}{oBlend}->{value}} = split /,\s*/, $ini->value('properties', $self->{properties}{oBlend}->{name});
	$self->{properties}{oClamp}->{name} = 'Texture clamp';
	$self->{properties}{oClamp}->{value} = $ini->value('properties', $self->{properties}{oClamp}->{name});
	$self->{properties}{oAREF}->{name} = 'Alpha ref';
	@{$self->{properties}{oAREF}->{value}} = split /,\s*/, $ini->value('properties', $self->{properties}{oAREF}->{name});
	$self->{properties}{oZTest}->{name} = 'Z-test';
	$self->{properties}{oZTest}->{value} = $ini->value('properties', $self->{properties}{oZTest}->{name});
	$self->{properties}{oZWrite}->{name} = 'Z-write';
	$self->{properties}{oZWrite}->{value} = $ini->value('properties', $self->{properties}{oZWrite}->{name});
	$self->{properties}{oLighting}->{name} = 'Lighting';
	$self->{properties}{oLighting}->{value} = $ini->value('properties', $self->{properties}{oLighting}->{name});
	$self->{properties}{oFog}->{name} = 'Fog';
	$self->{properties}{oFog}->{value} = $ini->value('properties', $self->{properties}{oFog}->{name});
	for (my $i = 0; $i < $self->{properties}{oBlend}->{value}->[1]; $i++) {
		my $set = {};
		$set->{ID} = $i;
		$set->{name} = $ini->value('sets', $set->{ID});
		push @{$self->{properties}{SETS}}, $set;
	}
}	
sub export {
	my $self = shift;
	my $ini = shift;
	
	$self->IBlender::export($ini);
	print $ini "\n[properties]\n";
	print $ini "$self->{properties}{oBlend}->{name} = ".join(',', @{$self->{properties}{oBlend}->{value}})."\n";
	print $ini "$self->{properties}{oClamp}->{name} = $self->{properties}{oClamp}->{value}\n" if ($self->{version} != 2);
	print $ini "$self->{properties}{oAREF}->{name} = ".join(',', @{$self->{properties}{oAREF}->{value}})."\n";
	print $ini "$self->{properties}{oZTest}->{name} = $self->{properties}{oZTest}->{value}\n";
	print $ini "$self->{properties}{oZWrite}->{name} = $self->{properties}{oZWrite}->{value}\n";
	print $ini "$self->{properties}{oLighting}->{name} = $self->{properties}{oLighting}->{value}\n";
	print $ini "$self->{properties}{oFog}->{name} = $self->{properties}{oFog}->{value}\n";
	print $ini "\n[sets]\n";
	foreach my $set (@{$self->{properties}{SETS}}) {
		print $ini "$set->{ID} = $set->{name}\n";
	}
}
#######################################################################
1;