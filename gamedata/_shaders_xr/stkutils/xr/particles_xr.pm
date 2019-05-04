# S.T.A.L.K.E.R. particles.xr handling module
# 11/08/2013	- added firstgen chunk unpacking
# 09/08/2013	- fixed bug with unpacking build files
# 22/08/2012	- initial release
##############################################
package stkutils::xr::particles_xr;
use strict;
use stkutils::data_packet;
use stkutils::ini_file;
use stkutils::debug qw(fail warn);
use stkutils::utils qw(get_filelist);
use File::Path;

use constant PS_CHUNK_VERSION => 1;
use constant PS_CHUNK_FIRSTGEN => 2;
use constant PS_CHUNK_PARTICLES_EFFECTS => 3;
use constant PS_CHUNK_PARTICLES_GROUPS => 4;

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
			$index == PS_CHUNK_VERSION && do{$self->read_version($CDH);last SWITCH;};
			$index == PS_CHUNK_FIRSTGEN && do{$self->read_firstgen($CDH, $mode);last SWITCH;};
			$index == PS_CHUNK_PARTICLES_EFFECTS && do{$self->read_peffects($CDH, $mode);last SWITCH;};
			$index == PS_CHUNK_PARTICLES_GROUPS && do{$self->read_pgroups($CDH, $mode);last SWITCH;};
			fail('unknown chunk index '.$index);
		}
		$CDH->r_chunk_close();
	}
	$CDH->close();
}
sub read_version {
	my $self = shift;
	my ($CDH) = @_;	
#	print "	version = ";
	$self->{version} = unpack('v', ${$CDH->r_chunk_data()});
#	print "$self->{version}\n";
	fail('unsupported version '.$self->{version}) unless $self->{version} == 1;
}
sub read_firstgen {
	my $self = shift;
	my ($CDH, $mode) = @_;	
	my $rData = $CDH->r_chunk_data();
	my $count = unpack('V', substr($$rData, 0, 4));
	for (my $i = 0; $i < $count; ++$i)
	{
		my $p = firstgen->new(\substr($$rData, 4 + 0x248*$i, 0x248));
		$p->read('bin');
		push @{$self->{firstgen}}, $p;
	}
}
sub read_peffects {
	my $self = shift;
	my ($CDH, $mode) = @_;	
	print "	particle effects\n";
	while (1) {
		my ($index, $size) = $CDH->r_chunk_open();
		defined $index or last;
		my $CPEDef = particles_effect->new($CDH->r_chunk_data());
		$CPEDef->read('bin');
		push @{$self->{particles_effects}}, $CPEDef;
		$CDH->r_chunk_close();
	}
}
sub read_pgroups {
	my $self = shift;
	my ($CDH, $mode) = @_;	
	print "	particle groups\n";
	while (1) {
		my ($index, $size) = $CDH->r_chunk_open();
		defined $index or last;
		my $CPGDef = particles_group->new($CDH->r_chunk_data());
		$CPGDef->read($mode);
		push @{$self->{particles_groups}}, $CPGDef;
		$CDH->r_chunk_close();
	}
}
sub write {
	my $self = shift;
	my ($CDH, $mode) = @_;
	print "writing...\n";
	fail('unsuported mode '.$mode) unless ($mode eq 'ltx') or ($mode eq 'bin');
	
	$self->write_version($CDH);
	$self->write_firstgen($CDH, $mode);
	$self->write_peffects($CDH, $mode);
	$self->write_pgroups($CDH, $mode);
}
sub write_version {
	my $self = shift;
	my ($CDH) = @_;	
	print "	version\n";
	$CDH->w_chunk(PS_CHUNK_VERSION, pack('v', $self->{version}));
}
sub write_firstgen {
	my $self = shift;
	my ($CDH, $mode) = @_;	
	return if !defined $self->{firstgen};
	print "	firstgen\n";
	$CDH->w_chunk_open(PS_CHUNK_FIRSTGEN);
	$CDH->w_chunk_data(pack('V', $#{$self->{firstgen}} + 1));
	foreach my $effect (@{$self->{firstgen}}) {
		$effect->write($CDH, 'bin');
	}
	$CDH->w_chunk_close();
}
sub write_peffects {
	my $self = shift;
	my ($CDH, $mode) = @_;	
	print "	particle effects\n";
	$CDH->w_chunk_open(PS_CHUNK_PARTICLES_EFFECTS);
	my $i = 0;
	foreach my $effect (@{$self->{particles_effects}}) {
		$effect->write($CDH, 'bin', $i++);
	}
	$CDH->w_chunk_close();
}
sub write_pgroups {
	my $self = shift;
	my ($CDH, $mode) = @_;	
	print "	particle groups\n";
	$CDH->w_chunk_open(PS_CHUNK_PARTICLES_GROUPS);
	my $i = 0;
	foreach my $group (@{$self->{particles_groups}}) {
		$group->write($CDH, $mode, $i++);
	}
	$CDH->w_chunk_close();
}
sub export {
	my $self = shift;
	my ($folder, $mode) = @_;
	print "exporting...\n";
	File::Path::mkpath($folder, 0);
	chdir $folder or fail('cannot change dir to '.$folder);
	
	my $ini = IO::File->new('particles.ltx', 'w');
	print $ini "[general]\n";
	print $ini "version = $self->{version}\n";
	print $ini "effects_count = ".($#{$self->{particles_effects}} + 1)."\n";
	print $ini "groups_count = ".($#{$self->{particles_groups}} + 1)."\n";
	$ini->close();
	$self->export_firstgen($mode);
	$self->export_effects($mode);
	$self->export_groups($mode);
}
sub export_firstgen {
	my $self = shift;
	my ($mode) = @_;
	return if ($#{$self->{firstgen}} == -1);
	print "	firstgen\n";
	foreach my $effect (@{$self->{firstgen}}) {
		$effect->export('bin');
	}
}
sub export_effects {
	my $self = shift;
	my ($mode) = @_;
	print "	particle effects\n";
	foreach my $effect (@{$self->{particles_effects}}) {
		$effect->export('bin');
	}
}
sub export_groups {
	my $self = shift;
	my ($mode) = @_;
	print "	particle groups\n";
	foreach my $group (@{$self->{particles_groups}}) {
		$group->export($mode);
	}
}
sub my_import {
	my $self = shift;
	my ($folder, $mode) = @_;
	print "importing...\n";
	my $ini = stkutils::ini_file->new($folder.'particles.ltx', 'r');
	$self->{version} = $ini->value('general', 'version');
	$ini->close();
	
	$self->import_firstgen($folder, $mode);
	$self->import_effects($folder, $mode);
	$self->import_groups($folder, $mode);	
}
sub import_firstgen {
	my $self = shift;
	my ($folder, $mode) = @_;
	my $ext = '.fg';
	$ext = '_firstgen.ltx' if $mode eq 'ltx';
	my $effects = get_filelist($folder, $ext);
	
	return if ($#{$effects} == -1);
	print "	firstgen\n";
	foreach my $path (@$effects) {
		my $effect = firstgen->new();
		$effect->import($path, 'bin');
		push @{$self->{firstgen}}, $effect;
	}	
}
sub import_effects {
	my $self = shift;
	my ($folder, $mode) = @_;
	print "	particle effects\n";
	my $ext = '.pe';
	$ext = '_effect.ltx' if $mode eq 'ltx';
	my $effects = get_filelist($folder, $ext);
	
	foreach my $path (@$effects) {
		my $effect = particles_effect->new();
		$effect->import($path, 'bin');
		push @{$self->{particles_effects}}, $effect;
	}	
}
sub import_groups {
	my $self = shift;
	my ($folder, $mode) = @_;
	print "	particle groups\n";
	my $ext = '.pg';
	$ext = '_group.ltx' if $mode eq 'ltx';
	my $groups = get_filelist($folder, $ext);
	
	foreach my $path (@$groups) {
		my $group = particles_group->new();
		$group->import($path, $mode);
		push @{$self->{particles_groups}}, $group;
	}	
}
#######################################################################
package firstgen;
use strict;
use stkutils::debug 'fail';

sub new {
	my $class = shift;
	my $self = {};
	$self->{service_flags} = 0;
	$self->{data} = '';
	$self->{data} = $_[0] if $#_ == 0;
	bless $self, $class;
	return $self;
}
sub read {
	my $self = shift;
	my ($mode) = @_;	
	$self->read_name();
}
sub read_name {
	my $self = shift;
	my $packet = stkutils::data_packet->new($self->{data});
	($self->{m_name}) = $packet->unpack('Z*');
}
sub write {
	my $self = shift;
	my ($CDH, $mode) = @_;	

#	if ($mode eq 'bin') {
		$CDH->w_chunk_data(${$self->{data}});
#	}
}
sub write_name {
	my $self = shift;
	my ($CDH) = @_;
	$CDH->w_chunk_data(pack('Z*', $self->{m_name}));
}
sub export {
	my $self = shift;
	my ($mode) = @_;	
	
	my @path = split(/\\/, $self->{m_name});
	my $name = pop @path;
	my $path = join('\\', 'firstgen', @path);  
	File::Path::mkpath($path, 0);
	
#	if ($mode eq 'bin') {
		my $fh = IO::File->new($path.'\\'.$name.'.fg', 'w');
		binmode $fh;
		$fh->write(${$self->{data}}, length(${$self->{data}}));
		$fh->close();
#	}
}
sub export_name {
	my $self = shift;
	my ($ini) = @_;
	print $ini "name = $self->{m_name}\n";
}
sub import {
	my $self = shift;
	my ($path, $mode) = @_;	
#	if ($mode eq 'bin') {
		$self->{m_name} = substr($path, 0, -3);
		$self->{m_name} =~ s/firstgen\\//;
		my $fh = IO::File->new($path, 'r');
		binmode $fh;
		my $data = '';
		$fh->read($data, ($fh->stat())[7]);
		$self->{data} = \$data;
		$fh->close();
#	}	
}
sub import_name {
	my $self = shift;
	my ($ini) = @_;
	$self->{m_name} = $ini->value('general', 'name');
}
#######################################################################
package particles_effect;
use strict;
use stkutils::debug 'fail';
use constant PED_CHUNK_VERSION => 1;
use constant PED_CHUNK_NAME => 2;
use constant PED_CHUNK_EFFECTDATA => 3;
use constant PED_CHUNK_ACTIONS => 4;
use constant PED_CHUNK_FLAGS => 5;
use constant PED_CHUNK_FRAME => 6;
use constant PED_CHUNK_SPRITE => 7;
use constant PED_CHUNK_TIMELIMIT => 8;
use constant PED_CHUNK_COLLISION => 33;
use constant PED_CHUNK_VEL_SCALE => 34;
use constant PED_CHUNK_DESC => 35;

use constant PED_CHUNK_UNK  => 36;

use constant PED_CHUNK_DEF_ROTATION => 37;

use constant  PAAvoidID        => 0;
use constant  PABounceID       => 1;
use constant  PACallActionListID_obsolette  => 2;
use constant  PACopyVertexBID  => 3;
use constant  PADampingID      => 4;
use constant  PAExplosionID    => 5;
use constant  PAFollowID       => 6;
use constant  PAGravitateID    => 7;
use constant  PAGravityID      => 8;
use constant  PAJetID          => 9;
use constant  PAKillOldID      => 0x0A;
use constant  PAMatchVelocityID  => 0x0B;
use constant  PAMoveID         => 0x0C;
use constant  PAOrbitLineID    => 0x0D;
use constant  PAOrbitPointID   => 0x0E;
use constant  PARandomAccelID  => 0x0F;
use constant  PARandomDisplaceID  => 0x10;
use constant  PARandomVelocityID  => 0x11;
use constant  PARestoreID      => 0x12;
use constant  PASinkID         => 0x13;
use constant  PASinkVelocityID  => 0x14;
use constant  PASourceID       => 0x15;
use constant  PASpeedLimitID   => 0x16;
use constant  PATargetColorID  => 0x17;
use constant  PATargetSizeID   => 0x18;
use constant  PATargetRotateID  => 0x19;
use constant  PATargetRotateDID  => 0x1A;
use constant  PATargetVelocityID  => 0x1B;
use constant  PATargetVelocityDID  => 0x1C;
use constant  PAVortexID       => 0x1D;
use constant  PATurbulenceID   => 0x1E;
use constant  PAScatterID      => 0x1F;
use constant  action_enum_force_dword  => 0xFFFFFFFF;

use constant FL_SOC => 0x2;

sub new {
	my $class = shift;
	my $self = {};
	$self->{service_flags} = 0;
	$self->{data} = '';
	$self->{data} = $_[0] if $#_ == 0;
	bless $self, $class;
	return $self;
}
sub read {
	my $self = shift;
	my ($mode) = @_;	
	my $CDH = stkutils::chunked->new($self->{data}, 'data');
	while (1) {
		my ($index, $size) = $CDH->r_chunk_open();
		defined $index or last;
#		last if (($mode eq 'bin') && $index > PED_CHUNK_NAME);
		SWITCH: {
			$index == PED_CHUNK_VERSION && do{$self->read_version($CDH);last SWITCH;};
			$index == PED_CHUNK_NAME && do{$self->read_name($CDH);last SWITCH;};
			($mode eq 'ltx') && $index == PED_CHUNK_EFFECTDATA && do{$self->read_effectdata ($CDH);last SWITCH;};
			($mode eq 'ltx') && $index == PED_CHUNK_ACTIONS && do{$self->read_actions($CDH);last SWITCH;};
			($mode eq 'ltx') && $index == PED_CHUNK_FLAGS && do{$self->read_flags($CDH);last SWITCH;};
			($mode eq 'ltx') && $index == PED_CHUNK_FRAME && do{$self->read_frame($CDH);last SWITCH;};
			$index == PED_CHUNK_SPRITE && do{$self->read_sprite($CDH);last SWITCH;};
			($mode eq 'ltx') && $index == PED_CHUNK_TIMELIMIT && do{$self->read_timelimit($CDH);last SWITCH;};
			($mode eq 'ltx') && $index == PED_CHUNK_COLLISION && do{$self->read_collision($CDH);last SWITCH;};
			($mode eq 'ltx') && $index == PED_CHUNK_VEL_SCALE && do{$self->read_vel_scale($CDH);last SWITCH;};
			($mode eq 'ltx') && $index == PED_CHUNK_DESC && do{$self->read_description($CDH);last SWITCH;};
			($mode eq 'ltx') && $index == PED_CHUNK_DEF_ROTATION && do{$self->read_def_rotation($CDH);last SWITCH;};
			fail('unknown chunk index '.$index) if ($mode eq 'ltx');
		}
		$CDH->r_chunk_close();
	}
	$CDH->close();
}
sub read_version {
	my $self = shift;
	my ($CDH) = @_;	
	$self->{version} = unpack('v', ${$CDH->r_chunk_data()});
	fail('unsupported version '.$self->{version}) unless $self->{version} == 1;
}
sub read_name {
	my $self = shift;
	my ($CDH) = @_;	
	my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
	($self->{m_name}) = $packet->unpack('Z*');
	fail('data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_effectdata {
	my $self = shift;
	my ($CDH) = @_;
	my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
	($self->{m_MaxParticles}) = $packet->unpack('V');
	fail('data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_actions {
	my $self = shift;
	my ($CDH) = @_;
	my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
	my ($count) = $packet->unpack('V', 4);
	for (my $i = 0; $i < $count; $i++) {
		my ($type) = $packet->unpack('V', 4);
		my $action = {};
		SWITCH: {
#			$type == PAAvoidID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PABounceID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PACallActionListID_obsolette && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PACopyVertexBID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PADampingID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PAExplosionID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PAFollowID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PAGravitateID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PAGravityID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PAJetID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PAKillOldID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PAMatchVelocityID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PAMoveID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PAOrbitLineID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PAOrbitPointID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PARandomAccelID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PARandomDisplaceID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PARandomVelocityID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PARestoreID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PASinkID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PASinkVelocityID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
			$type == PASourceID && do {$action = pa_source->new(); $action->read($packet); last SWITCH;};
#			$type == PASpeedLimitID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PATargetColorID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PATargetSizeID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PATargetRotateID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PATargetRotateDID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PATargetVelocityID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PATargetVelocityDID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PAVortexID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PATurbulenceID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
#			$type == PAScatterID && do {$action = pa_avoid->new(); $action->load($packet); last SWITCH;};
			fail('unknown type '.$type);
		}
		push @{$self->{m_Actions}}, $action;
	}
	fail('data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_flags {
	my $self = shift;
	my ($CDH) = @_;
	my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
	($self->{m_Flags}) = $packet->unpack('V');
	fail('data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_frame {
	my $self = shift;
	my ($CDH) = @_;
	my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
	@{$self->{m_fTexSize}} = $packet->unpack('f2', 8);
	@{$self->{reserved}} = $packet->unpack('f2', 8);
	($self->{m_iFrameDimX},
	$self->{m_iFrameCount},
	$self->{m_fSpeed}) = $packet->unpack('VVf', 12);
	fail('data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_sprite {
	my $self = shift;
	my ($CDH) = @_;
	my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
	($self->{m_ShaderName},
	$self->{m_TextureName}) = $packet->unpack('Z*Z*');
	fail('data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_timelimit {
	my $self = shift;
	my ($CDH) = @_;	
	my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
	($self->{m_fTimeLimit}) = $packet->unpack('f');
	fail('data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_collision {
	my $self = shift;
	my ($CDH) = @_;	
	my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
	($self->{m_fCollideOneMinusFriction},
	$self->{m_fCollideResilience},
	$self->{m_fCollideSqrCutoff}) = $packet->unpack('fff');
	fail('data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_vel_scale {
	my $self = shift;
	my ($CDH) = @_;	
	my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
	@{$self->{m_VelocityScale}} = $packet->unpack('f3');
	fail('data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_description {
	my $self = shift;
	my ($CDH) = @_;	
	$self->{service_flags} |= FL_SOC;
	my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
	($self->{m_Creator},
	$self->{m_Editor},
	$self->{m_CreateTime},
	$self->{m_EditTime}) = $packet->unpack('Z*Z*VV');
	fail('data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_def_rotation {
	my $self = shift;
	my ($CDH) = @_;	
	my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
	@{$self->{m_APDefaultRotation}} = $packet->unpack('f3');
	fail('data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
}
sub write {
	my $self = shift;
	my ($CDH, $mode, $index) = @_;	

	if ($mode eq 'bin') {
		$CDH->w_chunk($index, ${$self->{data}});
	} elsif ($mode eq 'ltx') {
		$CDH->w_chunk_open($index);
		$self->write_version($CDH);
		$self->write_name($CDH);
		$self->write_effectdata($CDH);
		$self->write_actions($CDH);
		$self->write_flags($CDH);
		$self->write_sprite($CDH) if (($self->{m_Flags} & 0x1) == 0x1);
		$self->write_frame($CDH) if (($self->{m_Flags} & 0x400) == 0x400);
		$self->write_timelimit($CDH) if (($self->{m_Flags} & 0x4000) == 0x4000);
		$self->write_collision($CDH) if (($self->{m_Flags} & 0x10000) == 0x10000);
		$self->write_vel_scale($CDH) if (($self->{m_Flags} & 0x40000) == 0x40000);
		$self->write_def_rotation($CDH) if (($self->{m_Flags} & 0x8000) == 0x8000);
		$self->write_description($CDH) if (($self->{service_flags} & FL_SOC) == FL_SOC);
		$CDH->w_chunk_close();
	}
}
sub export {
	my $self = shift;
	my ($mode) = @_;	
	
	my @path = split(/\\/, $self->{m_name});
	pop @path;
	my $path = join('\\', @path); 
	File::Path::mkpath($path, 0);
	
	if ($mode eq 'bin') {
#		print "$self->{m_name}\n";
		my $fh = IO::File->new($self->{m_name}.'.pe', 'w');	
		if (!defined $fh)
		{
			return;
		}
		binmode $fh;
		$fh->write(${$self->{data}}, length(${$self->{data}}));
		$fh->close();
	} elsif ($mode eq 'ltx') {
		my $fh = IO::File->new($self->{m_name}.'_effect.ltx', 'w');
		print $fh "[general]\n";
		$self->export_version($fh);
		$self->export_name($fh);
		$self->export_effectdata($fh);
		$self->export_actions($fh);
		$self->export_flags($fh);
		$self->export_sprite($fh) if (($self->{m_Flags} & 0x1) == 0x1);
		$self->export_frame($fh) if (($self->{m_Flags} & 0x400) == 0x400);
		$self->export_timelimit($fh) if (($self->{m_Flags} & 0x4000) == 0x4000);
		$self->export_collision($fh) if (($self->{m_Flags} & 0x10000) == 0x10000);
		$self->export_vel_scale($fh) if (($self->{m_Flags} & 0x40000) == 0x40000);
		$self->export_def_rotation($fh) if (($self->{m_Flags} & 0x8000) == 0x8000);
		$self->export_description($fh) if (($self->{service_flags} & FL_SOC) == FL_SOC);
		$fh->close();
	}	
}
sub import {
	my $self = shift;
	my ($path, $mode) = @_;	
	if ($mode eq 'bin') {
		$self->{m_name} = substr($path, 0, -3);
		my $fh = IO::File->new($path, 'r');
		binmode $fh;
		my $data = '';
		$fh->read($data, ($fh->stat())[7]);
		$self->{data} = \$data;
		$fh->close();
	} elsif ($mode eq 'ltx') {
		my $fh = stkutils::ini_file->new($path, 'r');
		$self->import_version($fh);
		$self->import_name($fh);
		$self->import_effectdata($fh);
		$self->import_actions($fh);
		$self->import_flags($fh);
		$self->import_sprite($fh) if (($self->{m_Flags} & 0x1) == 0x1);
		$self->import_frame($fh) if (($self->{m_Flags} & 0x400) == 0x400);
		$self->import_timelimit($fh) if (($self->{m_Flags} & 0x4000) == 0x4000);
		$self->import_collision($fh) if (($self->{m_Flags} & 0x10000) == 0x10000);
		$self->import_vel_scale($fh) if (($self->{m_Flags} & 0x40000) == 0x40000);
		$self->import_def_rotation($fh) if (($self->{m_Flags} & 0x8000) == 0x8000);
		$self->import_description($fh) if (($self->{service_flags} & FL_SOC) == FL_SOC);
		$fh->close();
	}		
}
#######################################################################
package particles_group;
use strict;
use stkutils::debug 'fail';

use constant PGD_CHUNK_VERSION => 1;
use constant PGD_CHUNK_NAME => 2;
use constant PGD_CHUNK_FLAGS => 3;
use constant PGD_CHUNK_EFFECTS => 4;
use constant PGD_CHUNK_TIMELIMIT => 5;
use constant PGD_CHUNK_DESC => 6;
use constant PGD_CHUNK_EFFECTS2 => 7;

use constant FL_OLD => 0x1;
use constant FL_SOC => 0x2;

sub new {
	my $class = shift;
	my $self = {};
	$self->{service_flags} = 0;
	$self->{data} = '';
	$self->{data} = $_[0] if $#_ == 0;
	bless $self, $class;
	return $self;
}
sub read {
	my $self = shift;
	my ($mode) = @_;	
	my $CDH = stkutils::chunked->new($self->{data}, 'data');
	while (1) {
		my ($index, $size) = $CDH->r_chunk_open();
		defined $index or last;	
#		last if (($mode eq 'bin') && $index > PGD_CHUNK_NAME);
		SWITCH: {
			$index == PGD_CHUNK_VERSION && do{$self->read_version($CDH);last SWITCH;};
			$index == PGD_CHUNK_NAME && do{$self->read_name($CDH);last SWITCH;};
			($mode eq 'ltx') && $index == PGD_CHUNK_FLAGS && do{$self->read_flags ($CDH);last SWITCH;};
			($mode eq 'ltx') && $index == PGD_CHUNK_EFFECTS && do{$self->read_effects($CDH);last SWITCH;};
			($mode eq 'ltx') && $index == PGD_CHUNK_TIMELIMIT && do{$self->read_timelimit($CDH);last SWITCH;};
			($mode eq 'ltx') && $index == PGD_CHUNK_DESC && do{$self->read_description($CDH);last SWITCH;};
			($mode eq 'ltx') && $index == PGD_CHUNK_EFFECTS2 && do{$self->read_effects2($CDH);last SWITCH;};
			fail('unknown chunk index '.$index) if($mode eq 'ltx');
		}
		$CDH->r_chunk_close();
	}
	$CDH->close();
}
sub read_version {
	my $self = shift;
	my ($CDH) = @_;	
	$self->{version} = unpack('v', ${$CDH->r_chunk_data()});
	fail('unsupported version '.$self->{version}) unless $self->{version} == 3;
}
sub read_name {
	my $self = shift;
	my ($CDH) = @_;	
	my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
	($self->{m_name}) = $packet->unpack('Z*');
	fail('data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_flags {
	my $self = shift;
	my ($CDH) = @_;
	my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
	($self->{m_flags}) = $packet->unpack('V', 4);
	fail('data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_effects {
	my $self = shift;
	my ($CDH) = @_;	
	my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
	my ($count) = $packet->unpack('V', 4);
	for (my $i = 0; $i < $count; $i++) {
		my $effect = {};
		($effect->{m_EffectName},
		$effect->{m_OnPlayChildName},
		$effect->{m_OnBirthChildName},
		$effect->{m_OnDeadChildName},
		$effect->{m_Time0},
		$effect->{m_Time1},
		$effect->{m_Flags}) = $packet->unpack('Z*Z*Z*Z*ffV');
		push @{$self->{effects}}, $effect;
	}
	fail('data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_effects2 {
	my $self = shift;
	my ($CDH) = @_;	
	my $packet = stkutils::data_packet($CDH->r_chunk_data());
	$self->{service_flags} |= FL_OLD;
	my ($count) = $packet->unpack('V', 4);
	for (my $i = 0; $i < $count; $i++) {
		my $effect = {};
		($effect->{m_EffectName},
		$effect->{m_OnPlayChildName},
		$effect->{m_Time0},
		$effect->{m_Time1},
		$effect->{m_Flags}) = $packet->unpack('Z*Z*ffV');
		push @{$self->{effects}}, $effect;
	}
	fail('data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_timelimit {
	my $self = shift;
	my ($CDH) = @_;	
	my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
	($self->{m_fTimeLimit}) = $packet->unpack('f', 4);
	fail('data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
}
sub read_description {
	my $self = shift;
	my ($CDH) = @_;	
	$self->{service_flags} |= FL_SOC;
	my $packet = stkutils::data_packet->new($CDH->r_chunk_data());
	($self->{m_Creator},
	$self->{m_Editor},
	$self->{m_CreateTime},
	$self->{m_EditTime}) = $packet->unpack('Z*Z*VV');
	fail('data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
}
sub write {
	my $self = shift;
	my ($CDH, $mode, $index) = @_;	

	if ($mode eq 'bin') {
		$CDH->w_chunk($index, ${$self->{data}});
	} elsif ($mode eq 'ltx') {
		$CDH->w_chunk_open($index);
		$self->write_version($CDH);
		$self->write_name($CDH);
		$self->write_flags($CDH);
		if (($self->{service_flags} & FL_OLD) == 0) {
			$self->write_effects($CDH);
		} else {
			$self->write_effects2($CDH);
		}
		$self->write_timelimit($CDH);
		$self->write_description($CDH) if (($self->{service_flags} & FL_SOC) != 0);
		$CDH->w_chunk_close();
	}
}
sub write_version {
	my $self = shift;
	my ($CDH) = @_;
	$CDH->w_chunk(PGD_CHUNK_VERSION, pack('v', $self->{version}));
}
sub write_name {
	my $self = shift;
	my ($CDH) = @_;
	$CDH->w_chunk(PGD_CHUNK_NAME, pack('Z*', $self->{m_name}));
}
sub write_flags {
	my $self = shift;
	my ($CDH) = @_;
	$CDH->w_chunk(PGD_CHUNK_FLAGS, pack('V', $self->{m_flags}));
}
sub write_timelimit {
	my $self = shift;
	my ($CDH) = @_;
	$CDH->w_chunk(PGD_CHUNK_TIMELIMIT, pack('f', $self->{m_fTimeLimit}));
}
sub write_effects {
	my $self = shift;
	my ($CDH) = @_;
	$CDH->w_chunk_open(PGD_CHUNK_EFFECTS);
	$CDH->w_chunk_data(pack('V', $#{$self->{effects}} + 1));
	foreach my $effect (@{$self->{effects}}) {
		$CDH->w_chunk_data(pack('Z*Z*Z*Z*ffV', $effect->{m_EffectName}, $effect->{m_OnPlayChildName}, $effect->{m_OnBirthChildName}, $effect->{m_OnDeadChildName}, $effect->{m_Time0}, $effect->{m_Time1}, $effect->{m_Flags}));
	}
	$CDH->w_chunk_close();
}
sub write_effects2 {
	my $self = shift;
	my ($CDH) = @_;
	$CDH->w_chunk_open(PGD_CHUNK_EFFECTS2);
	$CDH->w_chunk_data(pack('V', $#{$self->{effects}} + 1));
	foreach my $effect (@{$self->{effects}}) {
		$CDH->w_chunk_data(pack('Z*Z*ffV', $effect->{m_EffectName}, $effect->{m_OnPlayChildName}, $effect->{m_Time0}, $effect->{m_Time1}, $effect->{m_Flags}));
	}
	$CDH->w_chunk_close();
}
sub write_description {
	my $self = shift;
	my ($CDH) = @_;	
	$CDH->w_chunk(PGD_CHUNK_DESC, pack('Z*Z*VV', $self->{m_Creator}, $self->{m_Editor}, $self->{m_CreateTime}, $self->{m_EditTime}));
}
sub export {
	my $self = shift;
	my ($mode) = @_;	
	
	my @path = split(/\\/, $self->{m_name});
	pop @path;
	my $path = join('\\', @path);  
	File::Path::mkpath($path, 0);
	
	if ($mode eq 'bin') {
		my $fh = IO::File->new($self->{m_name}.'.pg', 'w');
		binmode $fh;
		$fh->write(${$self->{data}}, length(${$self->{data}}));
		$fh->close();
	} elsif ($mode eq 'ltx') {
		my $fh = IO::File->new($self->{m_name}.'_group.ltx', 'w');
		print $fh "[general]\n";
		$self->export_version($fh);
		print $fh "service_flags = $self->{service_flags}\n";
		$self->export_name($fh);
		$self->export_flags($fh);
		$self->export_timelimit($fh);
		$self->export_description($fh) if (($self->{service_flags} & FL_SOC) != 0);
		print $fh "\n[effects]\n";
		$self->export_effects($fh);
		$fh->close();
	}	
}
sub export_version {
	my $self = shift;
	my ($ini) = @_;
	print $ini "version = $self->{version}\n";
}
sub export_name {
	my $self = shift;
	my ($ini) = @_;
	print $ini "name = $self->{m_name}\n";
}
sub export_flags {
	my $self = shift;
	my ($ini) = @_;
	print $ini "flags = $self->{m_flags}\n";
}
sub export_effects {
	my $self = shift;
	my ($ini) = @_;
	my $i = 0;
	print $ini "effects_count = ".($#{$self->{effects}} + 1)."\n";
	foreach my $effect (@{$self->{effects}}) {
		print $ini "$i:effect_name = $effect->{m_EffectName}\n";
		print $ini "$i:on_play = $effect->{m_OnPlayChildName}\n";
		print $ini "$i:on_birth = $effect->{m_OnBirthChildName}\n" if (($self->{service_flags} & FL_OLD) == 0);
		print $ini "$i:on_dead = $effect->{m_OnDeadChildName}\n" if (($self->{service_flags} & FL_OLD) == 0);
		print $ini "$i:begin_time = $effect->{m_Time0}\n";
		print $ini "$i:end_time = $effect->{m_Time1}\n";
		print $ini "$i:flags = $effect->{m_Flags}\n\n";
		$i++;
	}
}
sub export_timelimit {
	my $self = shift;
	my ($ini) = @_;
	print $ini "timelimit = $self->{m_fTimeLimit}\n";
}
sub export_description {
	my $self = shift;
	my ($ini) = @_;
	print $ini "creator = $self->{m_Creator}\n";
	print $ini "editor = $self->{m_Editor}\n";
	print $ini "create_time = $self->{m_CreateTime}\n";
	print $ini "edit_time = $self->{m_EditTime}\n";
}
sub import {
	my $self = shift;
	my ($path, $mode) = @_;	
	if ($mode eq 'bin') {
		$self->{m_name} = substr($path, 0, -3);
		my $fh = IO::File->new($path, 'r');
		binmode $fh;
		my $data = '';
		$fh->read($data, ($fh->stat())[7]);
		$self->{data} = \$data;
		$fh->close();
	} elsif ($mode eq 'ltx') {
		my $fh = stkutils::ini_file->new($path, 'r');
		$self->import_version($fh);
		$self->import_name($fh);
		$self->import_flags($fh);
		$self->{service_flags} = $fh->value('general', 'service_flags');
		$self->import_timelimit($fh);
		$self->import_description($fh) if (($self->{service_flags} & FL_SOC) != 0);
		$self->import_effects($fh);		
		$fh->close();
	}		
}
sub import_version {
	my $self = shift;
	my ($ini) = @_;
	$self->{version} = $ini->value('general', 'version');
}
sub import_name {
	my $self = shift;
	my ($ini) = @_;
	$self->{m_name} = $ini->value('general', 'name');
}
sub import_flags {
	my $self = shift;
	my ($ini) = @_;
	$self->{m_flags} = $ini->value('general', 'flags');
}
sub import_timelimit {
	my $self = shift;
	my ($ini) = @_;
	$self->{m_fTimeLimit} = $ini->value('general', 'timelimit');
}
sub import_description {
	my $self = shift;
	my ($ini) = @_;
	$self->{m_Creator} = $ini->value('general', 'creator');
	$self->{m_Editor} = $ini->value('general', 'editor');
	$self->{m_CreateTime} = $ini->value('general', 'create_time');
	$self->{m_EditTime} = $ini->value('general', 'edit_time');
}
sub import_effects {
	my $self = shift;
	my ($ini) = @_;
	my $count = $ini->value('effects', 'effects_count');
	for (my $i = 0; $i < $count; $i++){
		my $effect = {};
		$effect->{m_EffectName} = $ini->value('effects', "$i:effect_name");
		$effect->{m_OnPlayChildName} = $ini->value('effects', "$i:on_play");
		$effect->{m_OnBirthChildName} = $ini->value('effects', "$i:on_birth");
		$effect->{m_OnDeadChildName} = $ini->value('effects', "$i:on_dead");
		$effect->{m_Time0} = $ini->value('effects', "$i:begin_time");
		$effect->{m_Time1} = $ini->value('effects', "$i:end_time");
		$effect->{m_Flags} = $ini->value('effects', "$i:flags");
		push @{$self->{effects}}, $effect;
	}
}
#######################################################################
package pa_source;
use strict;
sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;
	return $self;
}
sub read {
	my $self = shift;
	my ($packet) = @_;	
	($self->{m_Flags},
	$self->{type}) = $packet->unpack('VV', 8);
	@{$self->{position}} = $packet->unpack('Vf16', 68);
	@{$self->{velocity}} = $packet->unpack('Vf16', 68);
	@{$self->{rot}} = $packet->unpack('Vf16', 68);
	@{$self->{size}} = $packet->unpack('Vf16', 68);
	@{$self->{color}} = $packet->unpack('Vf16', 68);
	($self->{alpha},
	$self->{particle_rate},
	$self->{age},
	$self->{age_sigma}) = $packet->unpack('ffff', 16);
	@{$self->{parent_vel}} = $packet->unpack('f3', 12);
	($self->{parent_motion}) = $packet->unpack('f', 4);
}
##############################
1;