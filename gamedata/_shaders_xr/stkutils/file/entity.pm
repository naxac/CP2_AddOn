# Module for stalker spawn reading
# Update history:
#	06/04/2014 - LA spawn unpacking added
#	27/08/2012 - fix code for new fail() syntax, add some new Artos stuff
#######################################################################
package stkutils::file::entity;
use strict;
use stkutils::scan;
use stkutils::data_packet;
use stkutils::debug qw(fail warn);
use constant FL_LEVEL_SPAWN => 0x01;
use constant FL_IS_2942 => 0x04;
use constant FL_IS_25XX => 0x08;
use constant FL_NO_FATAL => 0x10;
use constant FL_HANDLED => 0x20;
use constant FL_SAVE => 0x40;
use constant FL_LA => 0x80;

use vars qw(@ISA @EXPORT_OK);
require Exporter;

@ISA		= qw(Exporter);
@EXPORT_OK	= qw(FL_LEVEL_SPAWN FL_IS_2942 FL_IS_25XX FL_NO_FATAL FL_HANDLED FL_SAVE FL_LA);

sub new {
	my $class = shift;
	my $self = {};
	$self->{cse_object} = {};
	$self->{cse_object}->{client_data_path} = '';
	$self->{cse_object}->{flags} = 0;
	$self->{cse_object}->{ini} = undef;
	$self->{cse_object}->{user_ini} = undef;
	$self->{markers} = {};
	bless $self, $class;
	return $self;
}
sub init_abstract {cse_abstract::init($_[0]->{cse_object})}
sub init_object {$_[0]->{cse_object}->init()}
sub read {
	my $self = shift;
	my ($cf, $version) = @_;
	if (!$self->level()) {
		if ($version > 79) {
			while (1) {
				my ($index, $size) = $cf->r_chunk_open();
				defined($index) or last;
				my $id;
				if ($index == 0) {
					if ($version < 95) {
						$self->read_new($cf);
					} else {
						$id = unpack('v', ${$cf->r_chunk_data()});
					}
				} elsif ($index == 1) {
					if ($version < 95) {
						$id = unpack('v', ${$cf->r_chunk_data()});
					} else {
						$self->read_new($cf);
					}
				}
				$cf->r_chunk_close();
			}	
		} else {
			my $data = ${$cf->r_chunk_data()};
			my $size16 = unpack('v', substr($data, 0, 2));
			my $st_packet = stkutils::data_packet->new(\substr($data, 2, $size16));
			my $up_packet = stkutils::data_packet->new(\substr($data, $size16 + 4));
			$self->read_m_spawn($st_packet);
			$self->read_m_update($up_packet);
		}
	} else {
		$self->read_m_spawn(stkutils::data_packet->new($cf->r_chunk_data()));
	}
}
sub read_new {
	my $self = shift;
	my ($cf) = @_;
	while (1) {
		my ($index, $size) = $cf->r_chunk_open();
		defined($index) or last;
		my $data = ${$cf->r_chunk_data()};
		my $size16 = unpack('v', substr($data, 0, 2));
		$size16 == ($size - 2) or fail('alife object size mismatch');
		my $packet = stkutils::data_packet->new(\substr($data, 2));
		if ($index == 0) {
			$self->read_m_spawn($packet);
		} elsif ($index == 1) {
			$self->read_m_update($packet);
		}
		$cf->r_chunk_close();
	}
}
sub read_m_spawn {
	my $self = shift;
	my ($packet) = @_;
	$self->init_abstract();
	cse_abstract::state_read($self->{cse_object}, $packet);
	my $sName = lc($self->{cse_object}->{section_name});
	my $class_name;
	$class_name = $self->{cse_object}->{user_ini}->value('sections', "'$sName'") if (defined $self->{cse_object}->{user_ini});
	if (defined $self->{cse_object}->{ini} && !defined $class_name) {
		$class_name = $self->{cse_object}->{ini}->value('sections', "'$sName'")
	}
	defined $class_name or $class_name = stkutils::scan->get_class($sName) or fail('unknown class for section '.$self->{cse_object}->{section_name});
	bless $self->{cse_object}, $class_name;
#print "$class_name\n";
	fail('unknown clsid '.$class_name.' for section '.$self->{cse_object}->{section_name}) if !UNIVERSAL::can($self->{cse_object}, 'state_read');
	# handle SCRPTZN
	if ($self->{cse_object}->{version} > 118){
		bless $self->{cse_object}, 'se_sim_faction' if ($sName eq 'sim_faction');
	}	
	# handle wrong classes for weapon in ver 118
	if ($self->{cse_object}->{version} == 118 && $self->{cse_object}->{script_version} > 5){
		# soc
		bless $self->{cse_object}, 'cse_alife_item_weapon_magazined' if $sName =~ /ak74u|vintore/;
	}
	$self->init_object();
	$self->{cse_object}->state_read($packet);
	# shut up warnings for smart covers with extra data (acdccop bug)
	$packet->resid() == 0 or return if ((ref($self->{cse_object}) eq 'se_smart_cover') && ($packet->resid() % 2 == 0));
	# correct reading check
	$packet->resid() == 0 or warn('state data left ['.$packet->resid().'] in entity '.$self->{cse_object}->{name});
}
sub read_m_update {
	my $self = shift;
	my ($packet) = @_;
	cse_abstract::update_read($self->{cse_object}, $packet);
	UNIVERSAL::can($self->{cse_object}, 'update_read') && do {$self->{cse_object}->update_read($packet)};
	$packet->resid() == 0 or $self->error(__PACKAGE__.'::read_m_update', __LINE__, '$packet->resid() == 0', 'update data left ['.$packet->resid().'] in entity '.$self->{cse_object}->{name});		
}
sub write {
	my $self = shift;
	my ($cf, $object_id) = @_;
	if (!$self->level()) {
		if ($self->version() > 79) {
			if ($self->version() > 94) {
				$cf->w_chunk(0, pack('v', $object_id));
				$cf->w_chunk_open(1);
			} else {
				$cf->w_chunk_open(0);
			}
			
			$cf->w_chunk_open(0);
			$self->write_m_spawn($cf, $object_id);
			$cf->w_chunk_close();
			
			$cf->w_chunk_open(1);
			$self->write_m_update($cf);
			$cf->w_chunk_close();

			$cf->w_chunk_close();
			if ($self->version() <= 94) {
				$cf->w_chunk(1, pack('v', $object_id));
			}	
		} else {
			$self->write_m_spawn($cf, $object_id);
			$self->write_m_update($cf);
		}
	} else {
		$object_id = 0xFFFF;
		if ($self->{cse_object}->{section_name} eq 'graph_point') { 
			$object_id = 0xCCCC;
		}
		$self->write_m_spawn($cf, $object_id);
	}
}
sub write_m_spawn {
	my $self = shift;
	my ($cf, $object_id) = @_;
	my $obj_packet = stkutils::data_packet->new();
	$self->{cse_object}->state_write($obj_packet);
	my $abs_packet = stkutils::data_packet->new();
	cse_abstract::state_write($self->{cse_object}, $abs_packet, $object_id, $obj_packet->length() + 2);
	$cf->w_chunk_data(pack('v', $abs_packet->length() + $obj_packet->length())) if !$self->level();
	$cf->w_chunk_data($abs_packet->data());
	$cf->w_chunk_data($obj_packet->data());
}
sub write_m_update {
	my $self = shift;
	my ($cf) = @_;
	my $obj_upd_packet = stkutils::data_packet->new();
	UNIVERSAL::can($self->{cse_object}, 'update_write') && do {$self->{cse_object}->update_write($obj_upd_packet);};
	my $abs_upd_packet = stkutils::data_packet->new();
	cse_abstract::update_write($self->{cse_object}, $abs_upd_packet);
	$cf->w_chunk_data(pack('v', $abs_upd_packet->length() + $obj_upd_packet->length()));
	$cf->w_chunk_data($abs_upd_packet->data());
	$cf->w_chunk_data($obj_upd_packet->data());
}
sub import_ltx {
	my $self = shift;
	my ($if, $section, $import_type) = @_;
	$self->init_abstract();
	cse_abstract::state_import($self->{cse_object}, $if, $section, $import_type);
	my $sName = lc($self->{cse_object}->{section_name});
	my $class_name;
	$class_name = $self->{cse_object}->{user_ini}->value('sections', "'$sName'") if defined $self->{cse_object}->{user_ini};
	if (defined $self->{cse_object}->{ini} && !defined $class_name) {
		$class_name = $self->{cse_object}->{ini}->value('sections', "'$sName'")
	}
	defined $class_name or $class_name = stkutils::scan->get_class($sName) or fail('unknown class for section '.$self->{cse_object}->{section_name});
	bless $self->{cse_object}, $class_name;
	fail('unknown clsid '.$class_name.' for section '.$self->{cse_object}->{section_name}) if !UNIVERSAL::can($self->{cse_object}, 'state_import');
	if ($self->{cse_object}->{version} < 122){
		bless $self->{cse_object}, 'cse_alife_space_restrictor' if ($class_name eq 'se_sim_faction');
	}	
	if ($self->{cse_object}->{version} == 118 && $self->{cse_object}->{script_version} > 5){
		bless $self->{cse_object}, 'cse_alife_item_weapon_magazined' if $sName =~ /ak74u|vintore/;
	}
	$self->init_object();
	$self->{cse_object}->state_import($if, $section);
	UNIVERSAL::can($self->{cse_object}, 'update_import') && do {$self->{cse_object}->update_import($if, $section)} if !$self->level();
}
sub export_ltx {
	my $self = shift;
	my ($if, $id) = @_;

	my $fh = $if->{fh};
	print $fh "[$id]\n";
	cse_abstract::state_export($self->{cse_object}, $if);
	$self->{cse_object}->state_export($if);
	UNIVERSAL::can($self->{cse_object}, 'update_export') && do {$self->{cse_object}->update_export($if)} if !$self->level();
	print $fh "\n;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;\n\n";	
}
sub init_properties {
	my $self = shift;
	foreach my $p (@_) {
		next if defined $self->{$p->{name}};
		if (defined $p->{default}) {
			if (ref($p->{default}) eq 'ARRAY') {
				@{$self->{$p->{name}}} = @{$p->{default}};
			} else {
				$self->{$p->{name}} = $p->{default};
			}
		}
	}
}
sub version {return $_[0]->{cse_object}->{version}}
sub level {
	if ($_[0]->{cse_object}->{flags} & FL_LEVEL_SPAWN) {
		return 1;
	}
	return 0;
}
sub error {
	my $self = shift;
	if (!($self->{cse_object}->{flags} & FL_NO_FATAL)) {
		fail(@_)
	} else {
		warn(@_)
	}
}
#########################################################
package client_data;
use strict;
use stkutils::debug qw(fail warn);
sub new {
	my $class = shift;
	my ($packet, $size) = @_;
	my $self = {};
	$self->{pstor} = [];
	$self->{weather_manager} = {};
	$self->{treasure_manager} = {};
	$self->{task_manager} = {};
	$self->{psy_antenna} = {};
	$self->{data} = '';
	if ($#_ == 1) {
		$self->{data} = \substr($packet->data(), $packet->pos(), $size);
		$packet->pos($packet->pos() + $size);
	}
	bless $self, $class;
	return $self;
}
sub data {
	return $_[0]->{data} if $#_ == 0;
	$_[0]->{data} = $_[1];
}
sub read {
	my $self = shift;
	return;				#temporarily
	my $packet = stkutils::data_packet->new($self->data());

	#биндер
	$self->read_object_binder($packet);

	#сложность игры
	$self->{game_difficulty} = $packet->unpack('C', 1);
	my $load_treasure_manager = 0;
	if ($self->{game_difficulty} >= 128) {          
		$self->{game_difficulty} -= 128;
		$load_treasure_manager = 1;      
	}
	#время
	$self->{stored_input_time} = $packet->unpack('C', 1);
	if ($self->{stored_input_time} == 1) {
		$self->{disable_input_time} = $packet->unpack_ctime();
	}
	#пстор
	$self->read_pstor($packet);
	
	#погода
	($self->{weather_manager}->{update_level}, $self->{weather_manager}->{update_time}) = $packet->unpack('Z*V');

	#пси-антенна
	$self->read_psy_antenna($packet);

	#менеджер тайников
	if ($load_treasure_manager == 1) {
		$self->read_treasure_manager($packet);      
	}	
	
	#менеджер заданий
	$self->read_task_manager($packet);          

	#детектор
	my ($dflag) = $packet->unpack('C', 1);
	if ($dflag == 1) {
		$self->{detector}{init_time} = $packet->unpack_ctime();
		$self->{detector}{last_update_time} = $packet->unpack_ctime();
	}		
}
sub read_object_binder {
	my $self = shift;
	my ($packet) = @_;
	my $binder = $self->{object_binder};
	#CEntityAlive
	$binder->{st_enable_state} = $packet->unpack('C', 1);
	#???
	#CInventoryOwner
	$binder->{m_tmp_active_slot_num} = $packet->unpack('C', 1);
	$binder->{start_dialog} = $packet->unpack('Z*');
	$binder->{m_game_name} = $packet->unpack('Z*');
	$binder->{money} = $packet->unpack('V', 4);
	#CActor
	$binder->{m_pPhysics_support} = $packet->unpack('C', 1);
}
sub read_pstor {
	my $self = shift;
	my ($packet) = @_;
	my ($size) = $packet->unpack('V', 4);
	while (--$size) {
		my $var = {};
		($var->{name},
		$var->{type}) = $packet->unpack('Z*C');
		if ($var->{type} == 0) {
			($var->{value}) = $packet->unpack('V');
		} elsif ($var->{type} == 1) {
			($var->{value}) = $packet->unpack('Z*');
		} elsif ($var->{type} == 2) {
			($var->{value}) = $packet->unpack('C');
		}
		push @{$self->{pstor}}, $var;
	}
}
sub read_psy_antenna {
	my $self = shift;
	my ($packet) = @_;
	my ($flag) = $packet->unpack('C', 1);
	if ($flag == 1) {
		my $ant = $self->{psy_antenna};
		($ant->{hit_intensity},
		$ant->{sound_intensity},
		$ant->{sound_intensity_base},
		$ant->{mute_sound_threshold},
		$ant->{postprocess_count}) = $packet->unpack('ffffC', 13);
		for (my $i = 0; $i < $ant->{postprocess_count}; $i++) {
			my $pp = {};
			($pp->{k},
			$pp->{ii},
			$pp->{ib},
			$pp->{idx}) = $packet->unpack('Z*ffV');
			push @{$ant->{postprocesses}}, $pp;
		}
	}
}
sub read_treasure_manager {
	my $self = shift;
	my ($packet) = @_;

	my ($count) = $packet->unpack('v', 2);
	while (--$count) {
		my $tr = {};
		($tr->{target},
		$tr->{active},
		$tr->{done}) = $packet->unpack('VCC', 4);
		push @{$self->{treasure_manager}}, $tr;
	}
}
sub read_task_manager {
	my $self = shift;
	my ($packet) = @_;
	my ($task_count) = $packet->unpack('C', 1);
	while (--$task_count) {
		my $task = {};
		($task->{id},
		$task->{enabled},
		$task->{enabled_props},
		$task->{status},
		$task->{selected_target}) = $packet->unpack('Z*CCZ*l');
		$task->{last_task_time} = $packet->unpack_ctime();
		push @{$self->{task_manager}{full}}, $task;
	}	
	my ($active_task_count) = $packet->unpack('C', 1);
	while (--$active_task_count) {
		my $task = {};
		($task->{type},
		$task->{active_task_by_type}) = $packet->unpack('Z*Z*');
		push @{$self->{task_manager}{active}}, $task;
	}		
}

sub prepare {
	my $self = shift;
	my ($packet) = @_;
	return;				#temporarily
	$self->write_pstor($packet);
}
sub write {
	my $self = shift;
	my ($packet) = @_;
	$self->prepare($packet);
	$packet->data($packet->data().${$self->data()});
}
sub import {
	my ($self, $client_data_path, $id, $name) = @_;
	my $fh = IO::File->new($client_data_path.'/'.$id.'_'.$name.'.bin', 'r') or return;
	binmode $fh;
	my $data = '';
	$fh->read($data, ($fh->stat())[7]);
	$self->{data} = \$data;
	$fh->close();
}
sub export {
	my ($self, $client_data_path, $id, $name) = @_;
	my $fh = IO::File->new($client_data_path.'/'.$id.'_'.$name.'.bin', 'w');
	binmode $fh;
	$fh->write(${$self->{data}}, length(${$self->{data}}));
	$fh->close();
}
sub write_pstor {
	my $self = shift;
	my ($packet) = @_;
	$packet->pack('V', $#{$self->{pstor}} + 1);
	foreach (@{$self->{pstor}}) {
		$packet->pack('Z*C', $_->{name}, $_->{type});
		if ($_->{type} == 0) {
			$packet->pack('V', $_->{value});
		} elsif ($_->{type} == 1) {
			$packet->pack('Z*', $_->{value});
		} elsif ($_->{type} == 2) {
			$packet->pack('C', $_->{value});
		}
	}
}
#####################################
package cse_abstract;
use constant FL_SAVE => 0x40;
use strict;
use stkutils::debug qw(fail warn);
####	enum s_gameid
#use constant	GAME_ANY		=> 0;
#use constant	GAME_SINGLE		=> 0x01;
#use constant	GAME_DEATHMATCH	=> 0x02;
#use constant	GAME_CTF		=> 0x03;
#use constant	GAME_ASSAULT	=> 0x04;
#use constant	GAME_CS			=> 0x05;
#use constant	GAME_TEAMDEATHMATCH	=> 0x06;
#use constant	GAME_ARTEFACTHUNT	=> 0x07;
#use constant	GAME_LASTSTANDING	=> 0x64;
#use constant	GAME_DUMMY		=> 0xFF;
####	enum s_flags
use constant	FL_SPAWN_ENABLED		=> 0x01;
use constant	FL_SPAWN_ON_SURGE_ONLY		=> 0x02;
use constant	FL_SPAWN_SINGLE_ITEM_ONLY	=> 0x04;
use constant	FL_SPAWN_IF_DESTROYED_ONLY	=> 0x08;
use constant	FL_SPAWN_INFINITE_COUNT		=> 0x10;
use constant	FL_SPAWN_DESTROY_ON_SPAWN	=> 0x20;

use constant FULL_IMPORT => 0x0;
use constant NO_VERTEX_IMPORT => 0x1;

use constant properties_info => (
			{ name => 'dummy16',				type => 'h16',	default => 0x0001 },
			{ name => 'section_name',			type => 'sz',	default => '' },
			{ name => 'name',					type => 'sz',	default => '' },
			{ name => 's_gameid',				type => 'h8',	default => 0 },
			{ name => 's_rp',					type => 'h8',	default => 0xfe },
			{ name => 'position',				type => 'f32v3',default => [] },
			{ name => 'direction',				type => 'f32v3',default => [] },
			{ name => 'respawn_time',			type => 'h16',	default => 0 },
			{ name => 'id',						type => 'u16',	default => 0 },
			{ name => 'parent_id',				type => 'u16',	default => 65535 },
			{ name => 'phantom_id',				type => 'u16',	default => 65535 },
			{ name => 's_flags',				type => 'h16',	default => 0x21 },
			{ name => 'version',				type => 'u16',	default => 0 },
			{ name => 'cse_abstract__unk1_u16',	type => 'h16',	default => 0xFFFF },
			{ name => 'script_version',			type => 'u16',	default => 0 },
			{ name => 'spawn_probability',		type => 'f32',	default => 1.00 },
			{ name => 'spawn_flags',			type => 'u32',	default => 31 },
			{ name => 'spawn_control',			type => 'sz',	default => '' },
			{ name => 'max_spawn_count',		type => 'u32',	default => 1 },
			{ name => 'spawn_count',			type => 'u32',	default => 0 },
			{ name => 'last_spawn_time_old',	type => 'u8v8', default => [0,0,0,0,0,0,0,0]},
			{ name => 'min_spawn_interval',		type => 'u8v8', default => [0,0,0,0,0,0,0,0]},
			{ name => 'max_spawn_interval',		type => 'u8v8', default => [0,0,0,0,0,0,0,0]},
			{ name => 'spawn_id',				type => 'u16',	default => 0xFFFF },
);
sub init {
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	my $self = shift;
	my ($packet) = @_;
	$packet->unpack_properties($self, (properties_info)[0]);
	fail('cannot open M_SPAWN!') if $self->{'dummy16'} != 1;
	$packet->unpack_properties($self, (properties_info)[1..11]);
	if ($self->{s_flags} & FL_SPAWN_DESTROY_ON_SPAWN) {
		$packet->unpack_properties($self, (properties_info)[12]);
	}
	if ($self->{version} > 120) {
		$packet->unpack_properties($self, (properties_info)[13]);
	}
	if ($self->{version} > 69) {
		$packet->unpack_properties($self, (properties_info)[14]);
	}
	my ($client_data_size);
	if ($self->{version} > 93) {
		($client_data_size) = $packet->unpack('v', 2);
	} elsif ($self->{version} > 70) {
		($client_data_size) = $packet->unpack('C', 1);
	}
	if (defined $client_data_size and $client_data_size != 0) {
		$self->{client_data} = client_data->new($packet, $client_data_size);
		$self->{client_data}->read();
	}
	if ($self->{version} > 79) {
		$packet->unpack_properties($self, (properties_info)[23]);
	}
	if ($self->{version} < 112) {
		if ($self->{version} > 82) {
			$packet->unpack_properties($self, (properties_info)[15]);
		}
		if ($self->{version} > 83) {
			$packet->unpack_properties($self, (properties_info)[16..20]);
		}		
		if ($self->{version} > 84) {
			$packet->unpack_properties($self, (properties_info)[21..22]);
		}	
	}
	my $extended_size = $packet->unpack('v', 2);
}
sub state_write {
	my $self = shift;
	my ($packet, $spawn_id, $extended_size) = @_;
	$packet->pack_properties($self, (properties_info)[0..11]);
	if ($self->{s_flags} & FL_SPAWN_DESTROY_ON_SPAWN) {
		$packet->pack_properties($self, (properties_info)[12]);
	}
	if ($self->{version} > 120) {
		$packet->pack_properties($self, (properties_info)[13]);
	}
	if ($self->{version} > 69) {
		$packet->pack_properties($self, (properties_info)[14]);
	}
	my $len = length(${$self->{client_data}->data()}) if (defined $self->{client_data}->{data} && $self->{client_data}->{data} ne '');
	$len = 0 if !defined $len;
	if ($self->{version} > 93) {
		$packet->pack('v', $len);
	} elsif ($self->{version} > 70) {
		$packet->pack('C', $len);
	}
	$self->{client_data}->write($packet) if (defined $self->{client_data}->{data} && $self->{client_data}->{data} ne '');
	if ($self->{version} > 79) {
		if ($self->{flags} & FL_SAVE) {
			$packet->pack_properties($self, (properties_info)[23]);
		} else {
			$packet->pack('v', $spawn_id);
		}
	}
	if ($self->{version} < 112) {
		if ($self->{version} > 82) {
			$packet->pack_properties($self, (properties_info)[15]);
		}
		if ($self->{version} > 83) {
			$packet->pack_properties($self, (properties_info)[16..20]);
		}		
		if ($self->{version} > 84) {
			$packet->pack_properties($self, (properties_info)[21..22]);
		}	
	}
	$packet->pack('v', $extended_size);		
}
sub update_read {
	my ($size) = $_[1]->unpack('v', 2);
	fail('cannot open M_UPDATE!') unless $size == 0;
}
sub update_write {
	$_[1]->pack('v', 0);
}
sub state_import {
	$_[1]->import_properties($_[2], $_[0], (properties_info)[0..11]);
	if (($_[0]->{s_flags} & FL_SPAWN_DESTROY_ON_SPAWN) && ($_[3] == FULL_IMPORT)) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[12]);
	}
	if ($_[0]->{version} > 120) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[13]);
	}
	if (($_[0]->{version} > 69) && ($_[3] == FULL_IMPORT)) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[14]);
	}
	if ($_[0]->{version} < 112) {
		if ($_[0]->{version} > 82) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[15]);
		}
		if ($_[0]->{version} > 83) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[16..20]);
		}		
		if ($_[0]->{version} > 84) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[21..22]);
		}	
	}	
	if ($_[0]->{version} > 79) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[23]);
	}
	$_[0]->{client_data} = client_data->new();
	$_[0]->{client_data}->import($_[0]->{client_data_path}, $_[0]->{id}, $_[0]->{name});
}
sub state_export {
	$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0..11]);
	if ($_[0]->{s_flags} & FL_SPAWN_DESTROY_ON_SPAWN) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[12]);
	}
	if ($_[0]->{version} > 120) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[13]);
	}
	if ($_[0]->{version} > 69) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[14]);
	}
	if ($_[0]->{version} < 112) {
		if ($_[0]->{version} > 82) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[15]);
		}
		if ($_[0]->{version} > 83) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[16..20]);
		}		
		if ($_[0]->{version} > 84) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[21..22]);
		}	
	}
	if ($_[0]->{version} > 79) {
		$_[1]->export_properties($_[2], $_[0], (properties_info)[23]);
	}
	if (defined $_[0]->{client_data} and $_[0]->{client_data}->{data} ne '') {
		$_[0]->{client_data}->export($_[0]->{client_data_path}, $_[0]->{id}, $_[0]->{name});
	}
}
#######################################################################
package cse_alife_graph_point;
use strict;
use constant properties_info => (
	{ name => 'connection_point_name',	type => 'sz',	default => '' },
	{ name => 'connection_level_id',	type => 's32',	default => -1 },
	{ name => 'connection_level_name',	type => 'sz',	default => '' },
	{ name => 'location0',			type => 'u8',	default => 0 },	
	{ name => 'location1',			type => 'u8',	default => 0 },
	{ name => 'location2',			type => 'u8',	default => 0 },	
	{ name => 'location3',			type => 'u8',	default => 0 },
);
sub init {
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	$_[1]->unpack_properties($_[0], (properties_info)[0]);
	if ($_[0]->{version} > 33) {
		$_[1]->unpack_properties($_[0], (properties_info)[2]);
	} else {
		$_[1]->unpack_properties($_[0], (properties_info)[1]);
	}
	$_[1]->unpack_properties($_[0], (properties_info)[3..6]);
}
sub state_write {
	$_[1]->pack_properties($_[0], (properties_info)[0]);
	if ($_[0]->{version} > 33) {
		$_[1]->pack_properties($_[0], (properties_info)[2]);
	} else {
		$_[1]->pack_properties($_[0], (properties_info)[1]);
	}
	$_[1]->pack_properties($_[0], (properties_info)[3..6]);
}
sub state_import {
	$_[1]->import_properties($_[2], $_[0], (properties_info)[0]);
	if ($_[0]->{version} > 33) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[2]);
	} else {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[1]);
	}
	$_[1]->import_properties($_[2], $_[0], (properties_info)[3..6]);
}
sub state_export {
	$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0]);
	if ($_[0]->{version} > 33) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[2]);
	} else {
		$_[1]->export_properties(undef, $_[0], (properties_info)[1]);
	}
	$_[1]->export_properties(undef, $_[0], (properties_info)[3..6]);
}
#######################################################################
package cse_shape;
use strict;
use constant properties_info => (
	{ name => 'shapes', type => 'shape', default => {} },
);
sub state_read {
	$_[1]->unpack_properties($_[0], properties_info);
}
sub state_write {
	$_[1]->pack_properties($_[0], properties_info);
}
sub state_import {
	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub state_export {
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
}
#######################################################################
package cse_visual;
use strict;
use constant flObstacle	=> 0x01;
use constant properties_info => (
	{ name => 'visual_name',	type => 'sz',	default => '' },
	{ name => 'visual_flags',	type => 'h8',	default => 0 },
);
sub init {
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	$_[1]->unpack_properties($_[0], (properties_info)[0]);
	if ($_[0]->{version} >= 104) {
		$_[1]->unpack_properties($_[0], (properties_info)[1]);
	}
}
sub state_write {
	$_[1]->pack_properties($_[0], (properties_info)[0]);
	if ($_[0]->{version} >= 104) {
		$_[1]->pack_properties($_[0], (properties_info)[1]);
	}
}
sub state_import {
	$_[1]->import_properties($_[2], $_[0], (properties_info)[0]);
	if ($_[0]->{version} >= 104) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[1]);
	}
}
sub state_export {
	$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0]);
	if ($_[0]->{version} >= 104) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[1]);
	}
}
#######################################################################
package cse_alife_object_dummy;
use strict;
use constant properties_info => (
	{ name => 'cse_alife_object_dummy__unk1_u8',	type => 'u8',	default => 0 },
);
sub init {
	stkutils::file::entity::init_properties($_[0], properties_info);
	cse_visual::init(@_);
}
sub state_read {
	$_[1]->unpack_properties($_[0], properties_info);
	cse_visual::state_read(@_);
}
sub state_write {
	$_[1]->pack_properties($_[0], properties_info);
	cse_visual::state_write(@_);
}
sub state_import {
	$_[1]->import_properties($_[2], $_[0], properties_info);
	cse_visual::state_import(@_);
}
sub state_export {
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
	cse_visual::state_export(@_);
}
#######################################################################
package cse_motion;
use strict;
use constant properties_info => (
	{ name => 'motion_name', type => 'sz', default => '' },
);
sub init {
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	$_[1]->unpack_properties($_[0], properties_info);
}
sub state_write {
	$_[1]->pack_properties($_[0], properties_info);
}
sub state_import {
	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub state_export {
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
}
#######################################################################
package cse_turret_mgun;
use strict;
sub init {
	cse_alife_dynamic_object_visual::init(@_);
}
sub state_read {
	cse_alife_dynamic_object_visual::state_read(@_);
}
sub state_write {
	cse_alife_dynamic_object_visual::state_write(@_);
}
sub state_import {
	cse_alife_dynamic_object_visual::state_import(@_);
}
sub state_export {
	cse_alife_dynamic_object_visual::state_export(@_);
}
#######################################################################
package cse_ph_skeleton;
use strict;
use constant properties_info => (
	{ name => 'skeleton_name',	type => 'sz',	default => '$editor' },
	{ name => 'skeleton_flags',	type => 'u8',	default => 0 },	
	{ name => 'source_id',		type => 'h16',	default => 0xffff },
	{ name => 'skeleton',		type => 'skeleton'},
);
sub init {
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	$_[1]->unpack_properties($_[0], (properties_info)[0..2]);
	if (($_[0]->{skeleton_flags} & 0x4) != 0) {
		$_[1]->unpack_properties($_[0], (properties_info)[3]);
	}
}
sub state_write {
	$_[1]->pack_properties($_[0], (properties_info)[0..2]);
	if (($_[0]->{skeleton_flags} & 0x4) != 0) {
		$_[1]->pack_properties($_[0], (properties_info)[3]);
	}
}
sub state_import {
	$_[1]->import_properties($_[2], $_[0], (properties_info)[0..2]);
	if (($_[0]->{skeleton_flags} & 0x4) != 0) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[3]);
	}
}
sub state_export {
	$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0..2]);
	if (($_[0]->{skeleton_flags} & 0x4) != 0) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[3]);
	}
}
#######################################################################
package cse_target_cs_cask; 																
use strict;
use constant properties_info => (
	{ name => 'cse_target_cs_cask__unk1_u8',	type => 'u8',	default => 0 },
);
sub init {
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	$_[1]->unpack_properties($_[0], properties_info);
}
sub state_write {
	$_[1]->pack_properties($_[0], properties_info);
}
sub state_import {
	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub state_export {
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
}
#######################################################################
package cse_target_cs_base; 																
use strict;
use constant properties_info => (
	{ name => 'cse_target_cs_base__unk1_f32',	type => 'f32',	default => 0 },
	{ name => 'team_id',	type => 'u8'},
);
sub init {
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	$_[1]->unpack_properties($_[0], properties_info);
}
sub state_write {
	$_[1]->pack_properties($_[0], properties_info);
}
sub state_import {
	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub state_export {
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
}
#######################################################################
package cse_alife_spawn_group; 													
use strict;
use constant properties_info => (
	{ name => 'group_probability', type => 'f32', default => 1.0},
);
sub init {
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	if ($_[0]->{version} <= 79) {
		$_[1]->unpack_properties($_[0], properties_info);
	}
}
sub state_write {
	if ($_[0]->{version} <= 79) {
		$_[1]->pack_properties($_[0], properties_info);
	}
}
sub state_import {
	if ($_[0]->{version} <= 79) {
		$_[1]->import_properties($_[2], $_[0], properties_info);
	}
}
sub state_export {
	if ($_[0]->{version} <= 79) {
		$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
	}
}
#######################################################################
package cse_alife_object;
use strict;
use constant flUseSwitches		=> 0x00000001;
use constant flSwitchOnline		=> 0x00000002;
use constant flSwitchOffline		=> 0x00000004;
use constant flInteractive		=> 0x00000008; 
use constant flVisibleForAI		=> 0x00000010;
use constant flUsefulForAI		=> 0x00000020;
use constant flOfflineNoMove		=> 0x00000040;
use constant flUsedAI_Locations		=> 0x00000080;
use constant flUseGroupBehaviour	=> 0x00000100;
use constant flCanSave			=> 0x00000200;
use constant flVisibleForMap		=> 0x00000400;
use constant flUseSmartTerrains		=> 0x00000800;
use constant flCheckForSeparator	=> 0x00001000;
use constant flCorpseRemoval		=> 0x00002000;
use constant properties_info => (
			{ name => 'cse_alife_object__unk1_u8',	type => 'u8',	default => 0 },
			{ name => 'spawn_probability',	type => 'f32',	default => 1.00 },
			{ name => 'spawn_id',	type => 's32',	default => -1 },
			{ name => 'cse_alife_object__unk2_u16',	type => 'u16',	default => 0 },	
			{ name => 'game_vertex_id',	type => 'u16',	default => 0xffff },
			{ name => 'distance',		type => 'f32',	default => 0.0 },
			{ name => 'direct_control',	type => 'u32',	default => 1 },
			{ name => 'level_vertex_id',	type => 'u32',	default => 0xffffffff },
			{ name => 'cse_alife_object__unk3_u16',	type => 'u16',	default => 0 },
			{ name => 'spawn_control',		type => 'sz',	default => '' },
			{ name => 'object_flags',	type => 'h32',	default => 0 },
			{ name => 'custom_data',	type => 'sz',	default => ''},	
			{ name => 'story_id',		type => 's32',	default => -1 },
			{ name => 'spawn_story_id',		type => 's32',	default => -1 },
);
sub init {
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	if ($_[0]->{version} <= 24) {
		$_[1]->unpack_properties($_[0], (properties_info)[0]);
	} elsif (($_[0]->{version} > 24) && ($_[0]->{version} < 83)) {
		$_[1]->unpack_properties($_[0], (properties_info)[1]);
	}
	if ($_[0]->{version} < 83) {
		$_[1]->unpack_properties($_[0], (properties_info)[2]);
	}
	if ($_[0]->{version} < 4) {
		$_[1]->unpack_properties($_[0], (properties_info)[3]);
	}
	$_[1]->unpack_properties($_[0], (properties_info)[4..5]);
	if ($_[0]->{version} >= 4) {
		$_[1]->unpack_properties($_[0], (properties_info)[6]);
	}
	if ($_[0]->{version} >= 8) {
		$_[1]->unpack_properties($_[0], (properties_info)[7]);
	}
	if (($_[0]->{version} > 22) && ($_[0]->{version} <= 79)) {
		$_[1]->unpack_properties($_[0], (properties_info)[8]);
	}
	if (($_[0]->{version} > 23) && ($_[0]->{version} <= 84)) {
		$_[1]->unpack_properties($_[0], (properties_info)[9]);
	}
	if ($_[0]->{version} > 49) {
		$_[1]->unpack_properties($_[0], (properties_info)[10]);
	}
	if ($_[0]->{version} > 57) {
		$_[1]->unpack_properties($_[0], (properties_info)[11]);
	}
	if ($_[0]->{version} > 61) {
		$_[1]->unpack_properties($_[0], (properties_info)[12]);
	}
	if ($_[0]->{version} > 111) {
		$_[1]->unpack_properties($_[0], (properties_info)[13]);
	}
}
sub state_write {
	if ($_[0]->{version} <= 24) {
		$_[1]->pack_properties($_[0], (properties_info)[0]);
	} elsif (($_[0]->{version} > 24) && ($_[0]->{version} < 83)) {
		$_[1]->pack_properties($_[0], (properties_info)[1]);
	}
	if ($_[0]->{version} < 83) {
		$_[1]->pack_properties($_[0], (properties_info)[2]);
	}
	if ($_[0]->{version} < 4) {
		$_[1]->pack_properties($_[0], (properties_info)[3]);
	}
	$_[1]->pack_properties($_[0], (properties_info)[4..5]);
	if ($_[0]->{version} >= 4) {
		$_[1]->pack_properties($_[0], (properties_info)[6]);
	}
	if ($_[0]->{version} >= 8) {
		$_[1]->pack_properties($_[0], (properties_info)[7]);
	}
	if (($_[0]->{version} > 22) && ($_[0]->{version} <= 79)) {
		$_[1]->pack_properties($_[0], (properties_info)[8]);
	}
	if (($_[0]->{version} > 23) && ($_[0]->{version} <= 84)) {
		$_[1]->pack_properties($_[0], (properties_info)[9]);
	}
	if ($_[0]->{version} > 49) {
		$_[1]->pack_properties($_[0], (properties_info)[10]);
	}
	if ($_[0]->{version} > 57) {
		$_[1]->pack_properties($_[0], (properties_info)[11]);
	}
	if ($_[0]->{version} > 61) {
		$_[1]->pack_properties($_[0], (properties_info)[12]);
	}
	if ($_[0]->{version} > 111) {
		$_[1]->pack_properties($_[0], (properties_info)[13]);
	}
}
sub state_import {
	if ($_[0]->{version} <= 24) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[0]);
	} elsif (($_[0]->{version} > 24) && ($_[0]->{version} < 83)) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[1]);
	}
	if ($_[0]->{version} < 83) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[2]);
	}
	if ($_[0]->{version} < 4) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[3]);
	}
	$_[1]->import_properties($_[2], $_[0], (properties_info)[4..5]);
	if ($_[0]->{version} >= 4) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[6]);
	}
	if ($_[0]->{version} >= 8) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[7]);
	}
	if (($_[0]->{version} > 22) && ($_[0]->{version} <= 79)) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[8]);
	}
	if (($_[0]->{version} > 23) && ($_[0]->{version} <= 84)) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[9]);
	}
	if ($_[0]->{version} > 49) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[10]);
	}
	if ($_[0]->{version} > 57) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[11]);
	}
	if ($_[0]->{version} > 61) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[12]);
	}
	if ($_[0]->{version} > 111) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[13]);
	}
}
sub state_export {
	if ($_[0]->{version} <= 24) {
		$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0]);
	} elsif (($_[0]->{version} > 24) && ($_[0]->{version} < 83)) {
		$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[1]);
	}
	if ($_[0]->{version} < 83) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[2]);
	}
	if ($_[0]->{version} < 4) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[3]);
	}
	my $pack;
	if ($_[0]->{version} >= 83) {
		$pack = __PACKAGE__;
	} else {
		$pack = undef;
	}
	$_[1]->export_properties($pack, $_[0], (properties_info)[4..5]);
	if ($_[0]->{version} >= 4) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[6]);
	}
	if ($_[0]->{version} >= 8) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[7]);
	}
	if (($_[0]->{version} > 22) && ($_[0]->{version} <= 79)) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[8]);
	}
	if (($_[0]->{version} > 23) && ($_[0]->{version} <= 84)) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[9]);
	}
	if ($_[0]->{version} > 49) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[10]);
	}
	if ($_[0]->{version} > 57) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[11]);
	}
	if ($_[0]->{version} > 61) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[12]);
	}
	if ($_[0]->{version} > 111) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[13]);
	}
}
#######################################################################
package cse_alife_dynamic_object;
use strict;
sub init {
	cse_alife_object::init(@_);
}
sub state_read {
	cse_alife_object::state_read(@_);
}
sub state_write {
	cse_alife_object::state_write(@_);
}
sub state_import {
	cse_alife_object::state_import(@_);
}
sub state_export {
	cse_alife_object::state_export(@_);
}
#######################################################################
package cse_alife_online_offline_group;
use strict;
use constant properties_info => (
	{ name => 'members', type => 'l32u16v', default => [] },
);
sub init {
	cse_alife_dynamic_object::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_dynamic_object::state_read(@_);
	$_[1]->unpack_properties($_[0], properties_info);
}
sub state_write {
	cse_alife_dynamic_object::state_write(@_);
	$_[1]->pack_properties($_[0], properties_info);
}
sub state_import {
	cse_alife_dynamic_object::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub state_export {
	cse_alife_dynamic_object::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
}
#######################################################################
package cse_alife_dynamic_object_visual;
use strict;
sub init {
	cse_alife_object::init(@_);
	cse_visual::init(@_);
}
sub state_read {
	cse_alife_object::state_read(@_);
	cse_visual::state_read(@_) if ($_[0]->{version} > 31);
}
sub state_write {
	cse_alife_object::state_write(@_);
	cse_visual::state_write(@_) if ($_[0]->{version} > 31);
}
sub state_import {
	cse_alife_object::state_import(@_);
	cse_visual::state_import(@_) if ($_[0]->{version} > 31);
}
sub state_export {
	cse_alife_object::state_export(@_);
	cse_visual::state_export(@_) if ($_[0]->{version} > 31);
}
#######################################################################
package cse_alife_object_climable;
use strict;
use constant properties_info => (
	{ name => 'game_material',	type => 'sz',	default => 'materials\\fake_ladders' },
);
sub init {
	cse_alife_object::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_object::state_read(@_) if ($_[0]->{version} > 99);
	cse_shape::state_read(@_);
	$_[1]->unpack_properties($_[0], properties_info) if ($_[0]->{version} >= 128);
}
sub state_write {
	cse_alife_object::state_write(@_) if ($_[0]->{version} > 99);
	cse_shape::state_write(@_);
	$_[1]->pack_properties($_[0], properties_info) if ($_[0]->{version} >= 128);
}
sub state_import {
	cse_alife_object::state_import(@_) if ($_[0]->{version} > 99);
	cse_shape::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], properties_info) if ($_[0]->{version} >= 128);
}
sub state_export {
	cse_alife_object::state_export(@_) if ($_[0]->{version} > 99);
	cse_shape::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info) if ($_[0]->{version} >= 128);
}
#######################################################################
package cse_alife_object_physic;
use strict;
use constant properties_info => (
	{ name => 'physic_type',	type => 'h32',	default => 0 },
	{ name => 'mass',		type => 'f32',	default => 0.0 },
	{ name => 'fixed_bones',	type => 'sz',	default => '' },
	{ name => 'startup_animation',	type => 'sz',	default => '' },
	{ name => 'skeleton_flags',		type => 'u8',	default => 0 },
	{ name => 'source_id',	type => 'u16',	default => 65535 },
);
use constant upd_properties_info => (
	{ name => 'upd:num_items',	type => 'h8',	default => 0 },	
	{ name => 'upd:ph_force',		type => 'f32v3',	default => [0.0, 0.0, 0.0] },
	{ name => 'upd:ph_torque',		type => 'f32v3',	default => [0.0, 0.0, 0.0] },
	{ name => 'upd:ph_position',		type => 'f32v3',	default => [0.0, 0.0, 0.0] },
	{ name => 'upd:ph_rotation',		type => 'f32v4',	default => [0.0, 0.0, 0.0, 0.0] },
	{ name => 'upd:ph_angular_velosity',		type => 'f32v3',	default => [0.0, 0.0, 0.0] },
	{ name => 'upd:ph_linear_velosity',		type => 'f32v3',	default => [0.0, 0.0, 0.0] },
	{ name => 'upd:enabled',		type => 'u8', default => 1},
);
sub init {
	cse_alife_dynamic_object_visual::init(@_);
	cse_ph_skeleton::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
	stkutils::file::entity::init_properties($_[0], upd_properties_info);
}
sub state_read {
	if ($_[0]->{version} >= 14) {
		if ($_[0]->{version} < 16) {
			cse_alife_dynamic_object::state_read(@_);
		} else {
			cse_alife_dynamic_object_visual::state_read(@_);
		}
		if ($_[0]->{version} < 32) {
			cse_visual::state_read(@_);
		}
	}
	if ($_[0]->{version} >= 64) {
		cse_ph_skeleton::state_read(@_);
	}
	$_[1]->unpack_properties($_[0], (properties_info)[0..1]);
	if ($_[0]->{version} > 9) {
		$_[1]->unpack_properties($_[0], (properties_info)[2]);
	}
	if (($_[0]->{version} > 28) && ($_[0]->{version} < 65)) {
		$_[1]->unpack_properties($_[0], (properties_info)[3]);
	}
	if ($_[0]->{version} < 64) {
		if ($_[0]->{version} > 39) {
			$_[1]->unpack_properties($_[0], (properties_info)[4]);
		}
		if ($_[0]->{version} > 56) {
			$_[1]->unpack_properties($_[0], (properties_info)[5]);
		}
	}
}
sub state_write {
	if ($_[0]->{version} >= 14) {
		if ($_[0]->{version} < 16) {
			cse_alife_dynamic_object::state_write(@_);
		} else {
			cse_alife_dynamic_object_visual::state_write(@_);
		}
		if ($_[0]->{version} < 32) {
			cse_visual::state_write(@_);
		}
	}
	if ($_[0]->{version} >= 64) {
		cse_ph_skeleton::state_write(@_);
	}
	$_[1]->pack_properties($_[0], (properties_info)[0..1]);
	if ($_[0]->{version} > 9) {
		$_[1]->pack_properties($_[0], (properties_info)[2]);
	}
	if (($_[0]->{version} > 28) && ($_[0]->{version} < 65)) {
		$_[1]->pack_properties($_[0], (properties_info)[3]);
	}
	if ($_[0]->{version} < 64) {
		if ($_[0]->{version} > 39) {
			$_[1]->pack_properties($_[0], (properties_info)[4]);
		}
		if ($_[0]->{version} > 56) {
			$_[1]->pack_properties($_[0], (properties_info)[5]);
		}
	}
}
sub update_read {
	stkutils::file::entity::init_properties($_[0], upd_properties_info);
	if (($_[0]->{version} >= 122) && ($_[0]->{version} <= 128)) {
		$_[1]->unpack_properties($_[0], (upd_properties_info)[0]);
		if ($_[0]->{'upd:num_items'} != 0) {
			$_[1]->unpack_properties($_[0], (upd_properties_info)[1..4]);
			my $flags = $_[0]->{'upd:num_items'} >> 5;
			if (($flags & 0x2) == 0) {
				$_[1]->unpack_properties($_[0], (upd_properties_info)[5]);
			}
			if (($flags & 0x4) == 0) {
				$_[1]->unpack_properties($_[0], (upd_properties_info)[6]);
			}
			$_[1]->unpack_properties($_[0], (upd_properties_info)[7]);  #actually bool. Dunno how to make better yet.
		}
	}
}
sub update_import {
	if (($_[0]->{version} >= 122) && ($_[0]->{version} <= 128)) {
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[0]);
		if ($_[0]->{'upd:num_items'} != 0) {
			$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[1..4]);
			my $flags = $_[0]->{'upd:num_items'} >> 5;
			if (($flags & 0x2) == 0) {
				$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[5]);
			}
			if (($flags & 0x4) == 0) {
				$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[6]);
			}
			$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[7]);  #actually bool. Dunno how to make better yet.
		}
	}
}
sub update_export {
	if (($_[0]->{version} >= 122) && ($_[0]->{version} <= 128)) {
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[0]);
		if ($_[0]->{'upd:num_items'} != 0) {
			$_[1]->export_properties(undef, $_[0], (upd_properties_info)[1..4]);
			my $flags = $_[0]->{'upd:num_items'} >> 5;
			if (($flags & 0x2) == 0) {
				$_[1]->export_properties(undef, $_[0], (upd_properties_info)[5]);
			}
			if (($flags & 0x4) == 0) {
				$_[1]->export_properties(undef, $_[0], (upd_properties_info)[6]);
			}
			$_[1]->export_properties(undef, $_[0], (upd_properties_info)[7]);
		}
	}
}
sub update_write {
		if (($_[0]->{version} >= 122) && ($_[0]->{version} <= 128)) {
			$_[1]->pack_properties($_[0], (upd_properties_info)[0]);
			if ($_[0]->{'upd:num_items'} != 0) {
				$_[1]->pack_properties($_[0], (upd_properties_info)[1..4]);
				my $flags = $_[0]->{'upd:num_items'} >> 5;
				if (($flags & 0x2) == 0) {
					$_[1]->pack_properties($_[0], (upd_properties_info)[5]);
				}
				if (($flags & 0x4) == 0) {
					$_[1]->pack_properties($_[0], (upd_properties_info)[6]);
				}
				$_[1]->pack_properties($_[0], (upd_properties_info)[7]);  #actually bool. Dunno how to make better yet.
			}
		}
}
sub state_import {
	if ($_[0]->{version} >= 14) {
		if ($_[0]->{version} < 16) {
			cse_alife_dynamic_object::state_import(@_);
		} else {
			cse_alife_dynamic_object_visual::state_import(@_);
		}
		if ($_[0]->{version} < 32) {
			cse_visual::state_import(@_);
		}
	}
	if ($_[0]->{version} >= 64) {
		cse_ph_skeleton::state_import(@_);
	}
	$_[1]->import_properties($_[2], $_[0], (properties_info)[0..1]);
	if ($_[0]->{version} > 9) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[2]);
	}
	if (($_[0]->{version} > 28) && ($_[0]->{version} < 65)) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[3]);
	}
	if ($_[0]->{version} < 64) {
		if ($_[0]->{version} > 39) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[4]);
		}
		if ($_[0]->{version} > 56) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[5]);
		}
	}
}
sub state_export {
	if ($_[0]->{version} >= 14) {
		if ($_[0]->{version} < 16) {
			cse_alife_dynamic_object::state_export(@_);
		} else {
			cse_alife_dynamic_object_visual::state_export(@_);
		}
		if ($_[0]->{version} < 32) {
			cse_visual::state_export(@_);
		}
	}
	if ($_[0]->{version} >= 64) {
		cse_ph_skeleton::state_export(@_);
	}
	$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0..1]);
	if ($_[0]->{version} > 9) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[2]);
	}
	if (($_[0]->{version} > 28) && ($_[0]->{version} < 65)) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[3]);
	}
	if ($_[0]->{version} < 64) {
		if ($_[0]->{version} > 39) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[4]);
		}
		if ($_[0]->{version} > 56) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[5]);
		}
	}
}
#######################################################################
package cse_alife_object_hanging_lamp;
use strict;
use constant flPhysic		=> 0x0001;
use constant flCastShadow	=> 0x0002;
use constant flR1		=> 0x0004;
use constant flR2		=> 0x0008;
use constant flTypeSpot		=> 0x0010;
use constant flPointAmbient	=> 0x0020;
use constant properties_info => (
	{ name => 'main_color',		type => 'h32',	default => 0x00ffffff },
	{ name => 'main_brightness',	type => 'f32',	default => 0.0 },
	{ name => 'main_color_animator',type => 'sz',	default => '' },
	{ name => 'cse_alife_object_hanging_lamp__unk1_sz',type => 'sz',	default => '' },
	{ name => 'cse_alife_object_hanging_lamp__unk2_sz',type => 'sz',	default => '' },
	{ name => 'main_range',		type => 'f32',	default => 0.0 },
	{ name => 'light_flags',	type => 'h16',	default => 0 },
	{ name => 'cse_alife_object_hanging_lamp__unk3_f32',type => 'f32',	default => 0 },	
	{ name => 'animation',	type => 'sz',	default => '$editor' },
	{ name => 'cse_alife_object_hanging_lamp__unk4_sz',type => 'sz',	default => '' },
	{ name => 'cse_alife_object_hanging_lamp__unk5_f32',type => 'f32',	default => 0 },
	{ name => 'lamp_fixed_bones',	type => 'sz',	default => '' },
	{ name => 'health',		type => 'f32',	default => 1.0 },
	{ name => 'main_virtual_size',	type => 'f32',	default => 0.0 },
	{ name => 'ambient_radius',	type => 'f32',	default => 0.0 },
	{ name => 'ambient_power',	type => 'f32',	default => 0.0 },
	{ name => 'ambient_texture',	type => 'sz',	default => '' },
	{ name => 'main_texture',	type => 'sz',	default => '' },
	{ name => 'main_bone',		type => 'sz',	default => '' },
	{ name => 'main_cone_angle',	type => 'f32',	default => 0.0 },
	{ name => 'glow_texture',	type => 'sz',	default => '' },
	{ name => 'glow_radius',	type => 'f32',	default => 0.0 },
	{ name => 'ambient_bone',	type => 'sz',	default => '' },
	{ name => 'cse_alife_object_hanging_lamp__unk6_f32',type => 'f32',	default => 0.0 },
	{ name => 'cse_alife_object_hanging_lamp__unk7_f32',type => 'f32',	default => 0.0 },
	{ name => 'cse_alife_object_hanging_lamp__unk8_f32',type => 'f32',	default => 0.0 },
	{ name => 'main_cone_angle_old_format',	type => 'q8',	default => 0.0 },
);
sub init {
	cse_alife_dynamic_object_visual::init(@_);
	cse_ph_skeleton::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	if ($_[0]->{version} > 20) {
		cse_alife_dynamic_object_visual::state_read(@_);
	}
	if ($_[0]->{version} >= 69) {
		cse_ph_skeleton::state_read(@_);
	}
	if ($_[0]->{version} < 32) {
		cse_visual::state_read(@_);
	}
	if ($_[0]->{version} < 49) {
		$_[1]->unpack_properties($_[0], (properties_info)[0]);
		$_[1]->unpack_properties($_[0], (properties_info)[2..5]);
		$_[1]->unpack_properties($_[0], (properties_info)[26]);
		if ($_[0]->{version} > 10) {
			$_[1]->unpack_properties($_[0], (properties_info)[1]);
		}
		if ($_[0]->{version} > 11) {
			$_[1]->unpack_properties($_[0], (properties_info)[6]);
		}
		if ($_[0]->{version} > 12) {
			$_[1]->unpack_properties($_[0], (properties_info)[7]);
		}
		if ($_[0]->{version} > 17) {
			$_[1]->unpack_properties($_[0], (properties_info)[8]);
		}
		if ($_[0]->{version} > 42) {
			$_[1]->unpack_properties($_[0], (properties_info)[9..10]);
		}
		if ($_[0]->{version} > 43) {
			$_[1]->unpack_properties($_[0], (properties_info)[11]);
		}
		if ($_[0]->{version} > 44) {
			$_[1]->unpack_properties($_[0], (properties_info)[12]);
		}
	} else {
		$_[1]->unpack_properties($_[0], (properties_info)[0..2]);
		$_[1]->unpack_properties($_[0], (properties_info)[5..6]);
		$_[1]->unpack_properties($_[0], (properties_info)[8]);
		$_[1]->unpack_properties($_[0], (properties_info)[11..12]);
	}
	if ($_[0]->{version} > 55) {
		$_[1]->unpack_properties($_[0], (properties_info)[13..21]);
	}
	if ($_[0]->{version} > 96) {
		$_[1]->unpack_properties($_[0], (properties_info)[22]);
	}
	if ($_[0]->{version} > 118) {
		$_[1]->unpack_properties($_[0], (properties_info)[23..25]);
	}
}
sub state_write {
	if ($_[0]->{version} > 20) {
		cse_alife_dynamic_object_visual::state_write(@_);
	}
	if ($_[0]->{version} >= 69) {
		cse_ph_skeleton::state_write(@_);
	}
	if ($_[0]->{version} < 32) {
		cse_visual::state_write(@_);
	}
	if ($_[0]->{version} < 49) {
		$_[1]->pack_properties($_[0], (properties_info)[0]);
		$_[1]->pack_properties($_[0], (properties_info)[2..5]);
		$_[1]->pack_properties($_[0], (properties_info)[26]);
		if ($_[0]->{version} > 10) {
			$_[1]->pack_properties($_[0], (properties_info)[1]);
		}
		if ($_[0]->{version} > 11) {
			$_[1]->pack_properties($_[0], (properties_info)[6]);
		}
		if ($_[0]->{version} > 12) {
			$_[1]->pack_properties($_[0], (properties_info)[7]);
		}
		if ($_[0]->{version} > 17) {
			$_[1]->pack_properties($_[0], (properties_info)[8]);
		}
		if ($_[0]->{version} > 42) {
			$_[1]->pack_properties($_[0], (properties_info)[9..10]);
		}
		if ($_[0]->{version} > 43) {
			$_[1]->pack_properties($_[0], (properties_info)[11]);
		}
		if ($_[0]->{version} > 44) {
			$_[1]->pack_properties($_[0], (properties_info)[12]);
		}
	} else {
		$_[1]->pack_properties($_[0], (properties_info)[0..2]);
		$_[1]->pack_properties($_[0], (properties_info)[5..6]);
		$_[1]->pack_properties($_[0], (properties_info)[8]);
		$_[1]->pack_properties($_[0], (properties_info)[11..12]);
	}
	if ($_[0]->{version} > 55) {
		$_[1]->pack_properties($_[0], (properties_info)[13..21]);
	}
	if ($_[0]->{version} > 96) {
		$_[1]->pack_properties($_[0], (properties_info)[22]);
	}
	if ($_[0]->{version} > 118) {
		$_[1]->pack_properties($_[0], (properties_info)[23..25]);
	}
}
sub state_import {
	if ($_[0]->{version} > 20) {
		cse_alife_dynamic_object_visual::state_import(@_);
	}
	if ($_[0]->{version} >= 69) {
		cse_ph_skeleton::state_import(@_);
	}
	if ($_[0]->{version} < 32) {
		cse_visual::state_import(@_);
	}
	if ($_[0]->{version} < 49) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[0]);
		$_[1]->import_properties($_[2], $_[0], (properties_info)[2..5]);
		$_[1]->import_properties($_[2], $_[0], (properties_info)[26]);
		if ($_[0]->{version} > 10) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[1]);
		}
		if ($_[0]->{version} > 11) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[6]);
		}
		if ($_[0]->{version} > 12) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[7]);
		}
		if ($_[0]->{version} > 17) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[8]);
		}
		if ($_[0]->{version} > 42) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[9..10]);
		}
		if ($_[0]->{version} > 43) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[11]);
		}
		if ($_[0]->{version} > 44) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[12]);
		}
	} else {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[0..2]);
		$_[1]->import_properties($_[2], $_[0], (properties_info)[5..6]);
		$_[1]->import_properties($_[2], $_[0], (properties_info)[8]);
		$_[1]->import_properties($_[2], $_[0], (properties_info)[11..12]);
	}
	if ($_[0]->{version} > 55) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[13..21]);
	}
	if ($_[0]->{version} > 96) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[22]);
	}
	if ($_[0]->{version} > 118) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[23..25]);
	}
}
sub state_export {
	if ($_[0]->{version} > 20) {
		cse_alife_dynamic_object_visual::state_export(@_);
	}
	if ($_[0]->{version} >= 69) {
		cse_ph_skeleton::state_export(@_);
	}
	if ($_[0]->{version} < 32) {
		cse_visual::state_export(@_);
	}
	if ($_[0]->{version} < 49) {
		$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0]);
		$_[1]->export_properties(undef, $_[0], (properties_info)[2..5]);
		$_[1]->export_properties(undef, $_[0], (properties_info)[26]);
		if ($_[0]->{version} > 10) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[1]);
		}
		if ($_[0]->{version} > 11) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[6]);
		}
		if ($_[0]->{version} > 12) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[7]);
		}
		if ($_[0]->{version} > 17) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[8]);
		}
		if ($_[0]->{version} > 42) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[9..10]);
		}
		if ($_[0]->{version} > 43) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[11]);
		}
		if ($_[0]->{version} > 44) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[12]);
		}
	} else {
		$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0..2]);
		$_[1]->export_properties(undef, $_[0], (properties_info)[5..6]);
		$_[1]->export_properties(undef, $_[0], (properties_info)[8]);
		$_[1]->export_properties(undef, $_[0], (properties_info)[11..12]);
	}
	if ($_[0]->{version} > 55) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[13..21]);
	}
	if ($_[0]->{version} > 96) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[22]);
	}
	if ($_[0]->{version} > 118) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[23..25]);
	}
}
#######################################################################
package cse_alife_object_projector;
use strict;
use constant properties_info => (
	{ name => 'main_color',		type => 'h32',	default => 0x00ffffff },
	{ name => 'main_color_animator',type => 'sz',	default => '' },
	{ name => 'animation',	type => 'sz',	default => '$editor' },
	{ name => 'ambient_radius',	type => 'f32',	default => 0.0 },
	{ name => 'main_cone_angle',	type => 'q8',	default => 0.0 },
	{ name => 'main_virtual_size',	type => 'f32',	default => 0.0 },
	{ name => 'glow_texture',	type => 'sz',	default => '' },
	{ name => 'glow_radius',	type => 'f32',	default => 0.0 },
	{ name => 'cse_alife_object_hanging_lamp__unk3_u8',	type => 'u16',	default => 0 },
);
sub init {
	cse_alife_dynamic_object_visual::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_dynamic_object_visual::state_read(@_);
	if ($_[0]->{version} < 48) {
		$_[1]->unpack_properties($_[0], (properties_info)[0..5]);
		if ($_[0]->{version} > 40) {
			$_[1]->unpack_properties($_[0], (properties_info)[6..7]);
		}
		if ($_[0]->{version} > 45) {
			$_[1]->unpack_properties($_[0], (properties_info)[8]);
		}
	}
}
sub state_write {
	cse_alife_dynamic_object_visual::state_write(@_);
	if ($_[0]->{version} < 48) {
		$_[1]->pack_properties($_[0], (properties_info)[0..5]);
		if ($_[0]->{version} > 40) {
			$_[1]->pack_properties($_[0], (properties_info)[6..7]);
		}
		if ($_[0]->{version} > 45) {
			$_[1]->pack_properties($_[0], (properties_info)[8]);
		}
	}
}
sub state_import {
	cse_alife_dynamic_object_visual::state_import(@_);
	if ($_[0]->{version} < 48) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[0..5]);
		if ($_[0]->{version} > 40) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[6..7]);
		}
		if ($_[0]->{version} > 45) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[8]);
		}
	}
}
sub state_export {
	cse_alife_dynamic_object_visual::state_export(@_);
	if ($_[0]->{version} < 48) {
		$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0..5]);
		if ($_[0]->{version} > 40) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[6..7]);
		}
		if ($_[0]->{version} > 45) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[8]);
		}
	}
}
#######################################################################
package cse_alife_inventory_box;
use strict;
use constant properties_info => (
	{ name => 'cse_alive_inventory_box__unk1_u8', type => 'u8', default => 1 },
	{ name => 'cse_alive_inventory_box__unk2_u8', type => 'u8', default => 0 },
	{ name => 'tip', type => 'sz', default => '' },
);
sub init {
	cse_alife_dynamic_object_visual::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_dynamic_object_visual::state_read(@_);
	if ($_[0]->{version} >= 128) {
		$_[1]->unpack_properties($_[0], properties_info);
	}
}
sub state_write {
	cse_alife_dynamic_object_visual::state_write(@_);
	if ($_[0]->{version} >= 128) {
		$_[1]->pack_properties($_[0], properties_info);
	}
}
sub state_import {
	cse_alife_dynamic_object_visual::state_import(@_);
	if ($_[0]->{version} >= 128) {
		$_[1]->import_properties($_[2], $_[0], properties_info);
	}
}
sub state_export {
	cse_alife_dynamic_object_visual::state_export(@_);
	if ($_[0]->{version} >= 128) {
		$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
	}
}
#######################################################################
package cse_alife_object_breakable;
use strict;
use constant properties_info => (
	{ name => 'health', type => 'f32', default => 1.0 },
);
sub init {
	cse_alife_dynamic_object_visual::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_dynamic_object_visual::state_read(@_);
	$_[1]->unpack_properties($_[0], properties_info);
}
sub state_write {
	cse_alife_dynamic_object_visual::state_write(@_);
	$_[1]->pack_properties($_[0], properties_info);
}
sub state_import {
	cse_alife_dynamic_object_visual::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub state_export {
	cse_alife_dynamic_object_visual::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
}
#######################################################################
package cse_alife_mounted_weapon;
use strict;
sub init {
	cse_alife_dynamic_object_visual::init(@_);
}
sub state_read {
	cse_alife_dynamic_object_visual::state_read(@_);
}
sub state_write {
	cse_alife_dynamic_object_visual::state_write(@_);
}
sub state_import {
	cse_alife_dynamic_object_visual::state_import(@_);
}
sub state_export {
	cse_alife_dynamic_object_visual::state_export(@_);
}
#######################################################################
package cse_alife_stationary_mgun;
use strict;
use constant upd_properties_info => (
	{ name => 'upd:working',		type => 'u8', default => 0},
	{ name => 'upd:dest_enemy_direction',	type => 'f32v3', default => [0.0, 0.0, 0.0]},
);
sub init {
	cse_alife_dynamic_object_visual::init(@_);
	stkutils::file::entity::init_properties($_[0], upd_properties_info);
}
sub state_read {
	cse_alife_dynamic_object_visual::state_read(@_);
}
sub state_write {
	cse_alife_dynamic_object_visual::state_write(@_);
}
sub state_import {
	cse_alife_dynamic_object_visual::state_import(@_);
}
sub state_export {
	cse_alife_dynamic_object_visual::state_export(@_);
}
sub update_read {
	$_[1]->unpack_properties($_[0], upd_properties_info);
}
sub update_write {
	$_[1]->pack_properties($_[0], upd_properties_info);
}
sub update_import {
	$_[1]->import_properties($_[2], $_[0], upd_properties_info);
}
sub update_export {
	$_[1]->export_properties(undef, $_[0], upd_properties_info);
}
#######################################################################
package cse_alife_ph_skeleton_object;
use strict;
sub init {
	cse_alife_dynamic_object_visual::init(@_);
	cse_ph_skeleton::init(@_);
}
sub state_read {
	cse_alife_dynamic_object_visual::state_read(@_);
	if ($_[0]->{version} >= 64) {
		cse_ph_skeleton::state_read(@_);
	}
}
sub state_write {
	cse_alife_dynamic_object_visual::state_write(@_);
	if ($_[0]->{version} >= 64) {
		cse_ph_skeleton::state_write(@_);
	}
}
sub state_import {
	cse_alife_dynamic_object_visual::state_import(@_);
	if ($_[0]->{version} >= 64) {
		cse_ph_skeleton::state_import(@_);
	}
}
sub state_export {
	cse_alife_dynamic_object_visual::state_export(@_);
	if ($_[0]->{version} >= 64) {
		cse_ph_skeleton::state_export(@_);
	}
}
#######################################################################
package cse_alife_car;
use strict;
use constant properties_info => (
	{ name => 'cse_alife_car__unk1_f32', type => 'f32', default => 1.0 },	
	{ name => 'health', type => 'f32', default => 1.0 },	
	{ name => 'g_team', type => 'u8', default => 0 },	
	{ name => 'g_squad', type => 'u8', default => 0 },	
	{ name => 'g_group', type => 'u8', default => 0 },		
);
sub init {
	cse_alife_dynamic_object_visual::init(@_);
	cse_ph_skeleton::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	if (($_[0]->{version} < 8) || ($_[0]->{version} > 16)) {
		cse_alife_dynamic_object_visual::state_read(@_);
	}
	if ($_[0]->{version} < 8) {
		$_[1]->unpack_properties($_[0], (properties_info)[2..4]);
	}
	if ($_[0]->{version} > 65) {
		cse_ph_skeleton::state_read(@_);
	}
	if (($_[0]->{version} > 52) && (($_[0]->{version} < 55))) {
		$_[1]->unpack_properties($_[0], (properties_info)[0]);
	}
	if ($_[0]->{version} > 92) {
		$_[1]->unpack_properties($_[0], (properties_info)[1]);
	}
#	if ($_[0]->{health} > 1.0) {
#		$_[0]->{health} *= 0.01;
#	}
}
sub state_write {
	if (($_[0]->{version} < 8) || ($_[0]->{version} > 16)) {
		cse_alife_dynamic_object_visual::state_write(@_);
	}
	if ($_[0]->{version} < 8) {
	$_[1]->pack_properties($_[0], (properties_info)[2..4]);
	}
	if ($_[0]->{version} > 65) {
		cse_ph_skeleton::state_write(@_);
	}
	if (($_[0]->{version} > 52) && (($_[0]->{version} < 55))) {
		$_[1]->pack_properties($_[0], (properties_info)[0]);
	}
	if ($_[0]->{version} > 92) {
		$_[1]->pack_properties($_[0], (properties_info)[1]);
	}
#	if ($_[0]->{health} > 1.0) {
#		$_[0]->{health} *= 0.01;
#	}
}
sub state_import {
	if (($_[0]->{version} < 8) || ($_[0]->{version} > 16)) {
		cse_alife_dynamic_object_visual::state_import(@_);
	}
	if ($_[0]->{version} < 8) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[2..4]);
	}
	if ($_[0]->{version} > 65) {
		cse_ph_skeleton::state_import(@_);
	}
	if (($_[0]->{version} > 52) && (($_[0]->{version} < 55))) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[0]);
	}
	if ($_[0]->{version} > 92) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[1]);
	}
}
sub state_export {
	if (($_[0]->{version} < 8) || ($_[0]->{version} > 16)) {
		cse_alife_dynamic_object_visual::state_export(@_);
	}
	if ($_[0]->{version} < 8) {
		$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[2..4]);
	}
	if ($_[0]->{version} > 65) {
		cse_ph_skeleton::state_export(@_);
	}
	if (($_[0]->{version} > 52) && (($_[0]->{version} < 55))) {
		$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0]);
	}
	if ($_[0]->{version} > 92) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[1]);
	}
}
#######################################################################
package cse_alife_helicopter;
use strict;
use constant properties_info => (
	{ name => 'cse_alife_helicopter__unk1_sz',	type => 'sz', default => '' },
	{ name => 'engine_sound',			type => 'sz', default => '' },
);
sub init {
	cse_alife_dynamic_object_visual::init(@_);
	cse_ph_skeleton::init(@_);
	cse_motion::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_dynamic_object_visual::state_read(@_);
	cse_motion::state_read(@_);
	if ($_[0]->{version} >= 69) {
		cse_ph_skeleton::state_read(@_);
	}
	$_[1]->unpack_properties($_[0], properties_info);
}
sub state_write {
	cse_alife_dynamic_object_visual::state_write(@_);
	cse_motion::state_write(@_);
	if ($_[0]->{version} >= 69) {
		cse_ph_skeleton::state_write(@_);
	}
	$_[1]->pack_properties($_[0], properties_info);
}
sub state_import {
	cse_alife_dynamic_object_visual::state_import(@_);
	cse_motion::state_import(@_);
	if ($_[0]->{version} >= 69) {
		cse_ph_skeleton::state_import(@_);
	}
	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub state_export {
	cse_alife_dynamic_object_visual::state_export(@_);
	cse_motion::state_export(@_);
	if ($_[0]->{version} >= 69) {
		cse_ph_skeleton::state_export(@_);
	}
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
}
#######################################################################
package cse_alife_creature_abstract;
use strict;
use constant FL_IS_25XX => 0x08;
use constant properties_info => (
	{ name => 'g_team',			type => 'u8',	default => 0xff },
	{ name => 'g_squad',			type => 'u8',	default => 0xff },
	{ name => 'g_group',			type => 'u8',	default => 0xff },
	{ name => 'health',			type => 'f32',	default => 1.0 },
	{ name => 'dynamic_out_restrictions',	type => 'l32u16v', default => [] },
	{ name => 'dynamic_in_restrictions',	type => 'l32u16v', default => [] },
	{ name => 'killer_id',			type => 'h16', default => 0xffff },
	{ name => 'game_death_time',		type => 'u8v8', default => [0,0,0,0,0,0,0,0] },
);
use constant upd_properties_info => (
	{ name => 'upd:health',		type => 'f32',	default => -1  },
	{ name => 'upd:timestamp',	type => 'h32',	default => 0xFFFF  },
	{ name => 'upd:creature_flags',	type => 'h8',	default => 0xFF  },	
	{ name => 'upd:position',	type => 'f32v3',	default => []  },
	{ name => 'upd:o_model',	type => 'f32',	default => 0  },
	{ name => 'upd:o_torso',	type => 'f32v3',	default => [0.0, 0.0, 0.0]  },
	{ name => 'upd:o_model',	type => 'q8',	default => 0  },
	{ name => 'upd:o_torso',	type => 'q8v3',	default => [0,0,0]  },
	{ name => 'upd:g_team',		type => 'u8',	default => 0  },	
	{ name => 'upd:g_squad',	type => 'u8',	default => 0  },	
	{ name => 'upd:g_group',	type => 'u8',	default => 0  },
	{ name => 'upd:health',		type => 'q16',	default => 0  },
	{ name => 'upd:health',		type => 'q16_old',	default => 0  },
	{ name => 'upd:cse_alife_creature_abstract__unk1_f32v3',		type => 'f32v3', default => [0.0, 0.0, 0.0]},
);
sub init {
	cse_alife_dynamic_object_visual::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
	stkutils::file::entity::init_properties($_[0], upd_properties_info);
}
sub state_read {
	cse_alife_dynamic_object_visual::state_read(@_);
	$_[1]->unpack_properties($_[0], (properties_info)[0..2]);
	if ($_[0]->{version} > 18) {
		$_[1]->unpack_properties($_[0], (properties_info)[3]);
	}
	if ($_[0]->{version} < 32) {
		cse_visual::state_read(@_);
	}	
	if ($_[0]->{version} > 87) {
		$_[1]->unpack_properties($_[0], (properties_info)[4..5]);
	}
	if ($_[0]->{version} > 94) {
		$_[1]->unpack_properties($_[0], (properties_info)[6]);
	}
	if ($_[0]->{version} > 115) {
		$_[1]->unpack_properties($_[0], (properties_info)[7]);
	}
}
sub state_write {
	cse_alife_dynamic_object_visual::state_write(@_);
	$_[1]->pack_properties($_[0], (properties_info)[0..2]);
	if ($_[0]->{version} > 18) {
		$_[1]->pack_properties($_[0], (properties_info)[3]);
	}
	if ($_[0]->{version} < 32) {
		cse_visual::state_write(@_);
	}	
	if ($_[0]->{version} > 87) {
		$_[1]->pack_properties($_[0], (properties_info)[4..5]);
	}
	if ($_[0]->{version} > 94) {
		$_[1]->pack_properties($_[0], (properties_info)[6]);
	}
	if ($_[0]->{version} > 115) {
		$_[1]->pack_properties($_[0], (properties_info)[7]);
	}
}
sub state_import {
	cse_alife_dynamic_object_visual::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], (properties_info)[0..2]);
	if ($_[0]->{version} > 18) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[3]);
	}
	if ($_[0]->{version} < 32) {
		cse_visual::state_import(@_);
	}	
	if ($_[0]->{version} > 87) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[4..5]);
	}
	if ($_[0]->{version} > 94) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[6]);
	}
	if ($_[0]->{version} > 115) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[7]);
	}
}
sub state_export {
	cse_alife_dynamic_object_visual::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0..2]);
	if ($_[0]->{version} > 18) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[3]);
	}
	if ($_[0]->{version} < 32) {
		cse_visual::state_export(@_);
	}	
	if ($_[0]->{version} > 87) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[4..5]);
	}
	if ($_[0]->{version} > 94) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[6]);
	}
	if ($_[0]->{version} > 115) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[7]);
	}
}
sub update_read {
	if ($_[0]->{version} > 109) {
		$_[1]->unpack_properties($_[0], (upd_properties_info)[0]);
	} elsif ($_[0]->{version} > 40) {
		$_[1]->unpack_properties($_[0], (upd_properties_info)[11]);
	} else {
		$_[1]->unpack_properties($_[0], (upd_properties_info)[12]);
	}
	if (($_[0]->{version} < 17) && (ref($_[0]) eq 'se_actor')) {
		$_[1]->unpack_properties($_[0], (upd_properties_info)[13]);
	}
	$_[1]->unpack_properties($_[0], (upd_properties_info)[1..3]);
	if (($_[0]->{version} > 117) && (!is_2588($_[0]))) {
		$_[1]->unpack_properties($_[0], (upd_properties_info)[4..5]);
	} else {
		if ($_[0]->{version} > 85) {
			$_[1]->unpack_properties($_[0], (upd_properties_info)[6]);
		}
		if ($_[0]->{version} > 63) {
			$_[1]->unpack_properties($_[0], (upd_properties_info)[7]);
		}
	}
	$_[1]->unpack_properties($_[0], (upd_properties_info)[8..10]);
}
sub update_write {
	if ($_[0]->{version} > 109) {
		$_[1]->pack_properties($_[0], (upd_properties_info)[0]);
	} elsif ($_[0]->{version} > 40) {
		$_[1]->pack_properties($_[0], (upd_properties_info)[11]);
	} else {
		$_[1]->pack_properties($_[0], (upd_properties_info)[12]);
	}
	if (($_[0]->{version} < 17) && (ref($_[0]) eq 'se_actor')) {
		$_[1]->pack_properties($_[0], (upd_properties_info)[13]);
	}
	$_[1]->pack_properties($_[0], (upd_properties_info)[1..3]);
	if (($_[0]->{version} > 117) && (!is_2588($_[0]))) {
		$_[1]->pack_properties($_[0], (upd_properties_info)[4..5]);
	} else {
		if ($_[0]->{version} > 85) {
			$_[1]->pack_properties($_[0], (upd_properties_info)[6]);
		}
		if ($_[0]->{version} > 63) {
			$_[1]->pack_properties($_[0], (upd_properties_info)[7]);
		}
	}
	$_[1]->pack_properties($_[0], (upd_properties_info)[8..10]);
}
sub update_import {
	if ($_[0]->{version} > 109) {
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[0]);
	} elsif ($_[0]->{version} > 40) {
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[11]);
	} else {
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[12]);
	}
	if (($_[0]->{version} < 17) && (ref($_[0]) eq 'se_actor')) {
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[13]);
	}
	$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[1..3]);
	if (($_[0]->{version} > 117) && (!is_2588($_[0]))) {
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[4..5]);
	} else {
		if ($_[0]->{version} > 85) {
			$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[6]);
		}
		if ($_[0]->{version} > 63) {
			$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[7]);
		}
	}
	$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[8..10]);
}
sub update_export {
	if ($_[0]->{version} > 109) {
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[0]);
	} elsif ($_[0]->{version} > 40) {
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[11]);
	} else {
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[12]);
	}
	if (($_[0]->{version} < 17) && (ref($_[0]) eq 'se_actor')) {
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[13]);
	}
	$_[1]->export_properties(undef, $_[0], (upd_properties_info)[1..3]);
	if (($_[0]->{version} > 117) && (!is_2588($_[0]))) {
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[4..5]);
	} else {
		if ($_[0]->{version} > 85) {
			$_[1]->export_properties(undef, $_[0], (upd_properties_info)[6]);
		}
		if ($_[0]->{version} > 63) {
			$_[1]->export_properties(undef, $_[0], (upd_properties_info)[7]);
		}
	}
	$_[1]->export_properties(undef, $_[0], (upd_properties_info)[8..10]);
}
sub is_2588 {return ($_[0]->{flags} & FL_IS_25XX)}
#######################################################################
package cse_alife_creature_crow;
use strict;
sub init {
	cse_alife_creature_abstract::init(@_);
	cse_visual::init(@_);
}
sub state_read {
	if ($_[0]->{version} > 20) {
		cse_alife_creature_abstract::state_read(@_);
		if ($_[0]->{version} < 32) {
			cse_visual::state_read(@_);
		}
	}
}
sub state_write {
	if ($_[0]->{version} > 20) {
		cse_alife_creature_abstract::state_write(@_);
		if ($_[0]->{version} < 32) {
			cse_visual::state_write(@_);
		}
	}
}
sub state_import {
	if ($_[0]->{version} > 20) {
		cse_alife_creature_abstract::state_import(@_);
		if ($_[0]->{version} < 32) {
			cse_visual::state_import(@_);
		}
	}
}
sub state_export {
	if ($_[0]->{version} > 20) {
		cse_alife_creature_abstract::state_export(@_);
		if ($_[0]->{version} < 32) {
			cse_visual::state_export(@_);
		}
	}
}
sub update_read {
	cse_alife_creature_abstract::update_read(@_);
}
sub update_write {
	cse_alife_creature_abstract::update_write(@_);
}
sub update_import {
	cse_alife_creature_abstract::update_import(@_);
}
sub update_export {
	cse_alife_creature_abstract::update_export(@_);
}
#######################################################################
package cse_alife_creature_phantom;
use strict;
sub init {
	cse_alife_creature_abstract::init(@_);
}
sub state_read {
	cse_alife_creature_abstract::state_read(@_);
}
sub state_write {
	cse_alife_creature_abstract::state_write(@_);
}
sub state_import {
	cse_alife_creature_abstract::state_import(@_);
}
sub state_export {
	cse_alife_creature_abstract::state_export(@_);
}
sub update_read {
	cse_alife_creature_abstract::update_read(@_);
}
sub update_write {
	cse_alife_creature_abstract::update_write(@_);
}
sub update_import {
	cse_alife_creature_abstract::update_import(@_);
}
sub update_export {
	cse_alife_creature_abstract::update_export(@_);
}
#######################################################################
package cse_alife_monster_abstract;
use strict;
use constant properties_info => (
	{ name => 'base_out_restrictors',	type => 'sz',	default => '' },
	{ name => 'base_in_restrictors',	type => 'sz',	default => '' },
	{ name => 'smart_terrain_id',		type => 'u16',	default => 65535 },
	{ name => 'smart_terrain_task_active',	type => 'u8',	default => 0 },
);
use constant upd_properties_info => (
	{ name => 'upd:next_game_vertex_id',	type => 'u16',	default => 0xFFFF },
	{ name => 'upd:prev_game_vertex_id',	type => 'u16',	default => 0xFFFF },
	{ name => 'upd:distance_from_point',	type => 'f32',	default => 0 },
	{ name => 'upd:distance_to_point',	type => 'f32',	default => 0 },
	{ name => 'upd:cse_alife_monster_abstract__unk1_u32',	type => 'u32',	default => 0 },
	{ name => 'upd:cse_alife_monster_abstract__unk2_u32',	type => 'u32',	default => 0 },
);
sub init {
	cse_alife_creature_abstract::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
	stkutils::file::entity::init_properties($_[0], upd_properties_info);
}
sub state_read {
	cse_alife_creature_abstract::state_read(@_);
	if ($_[0]->{version} > 72) {
		$_[1]->unpack_properties($_[0], (properties_info)[0]);
	}
	if ($_[0]->{version} > 73) {
		$_[1]->unpack_properties($_[0], (properties_info)[1]);
	}
	if ($_[0]->{version} > 111) {
		$_[1]->unpack_properties($_[0], (properties_info)[2]);
	}	
	if ($_[0]->{version} > 113) {
		$_[1]->unpack_properties($_[0], (properties_info)[3]);
	}
}
sub state_write {
	cse_alife_creature_abstract::state_write(@_);
	if ($_[0]->{version} > 72) {
		$_[1]->pack_properties($_[0], (properties_info)[0]);
	}
	if ($_[0]->{version} > 73) {
		$_[1]->pack_properties($_[0], (properties_info)[1]);
	}
	if ($_[0]->{version} > 111) {
		$_[1]->pack_properties($_[0], (properties_info)[2]);
	}	
	if ($_[0]->{version} > 113) {
		$_[1]->pack_properties($_[0], (properties_info)[3]);
	}
}
sub state_import {
	cse_alife_creature_abstract::state_import(@_);
	if ($_[0]->{version} > 72) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[0]);
	}
	if ($_[0]->{version} > 73) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[1]);
	}
	if ($_[0]->{version} > 111) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[2]);
	}	
	if ($_[0]->{version} > 113) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[3]);
	}
}
sub state_export {
	cse_alife_creature_abstract::state_export(@_);
	if ($_[0]->{version} > 72) {
		$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0]);
	}
	if ($_[0]->{version} > 73) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[1]);
	}
	if ($_[0]->{version} > 111) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[2]);
	}	
	if ($_[0]->{version} > 113) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[3]);
	}
}
sub update_read {
	cse_alife_creature_abstract::update_read(@_);
	$_[1]->unpack_properties($_[0], (upd_properties_info)[0..3]);
	if ($_[0]->{version} <= 79) {
		$_[1]->unpack_properties($_[0], (upd_properties_info)[4..5]);
	}
}
sub update_write {
	cse_alife_creature_abstract::update_write(@_);
	$_[1]->pack_properties($_[0], (upd_properties_info)[0..3]);
	if ($_[0]->{version} <= 79) {
		$_[1]->pack_properties($_[0], (upd_properties_info)[4..5]);
	}
}
sub update_import {
	cse_alife_creature_abstract::update_import(@_);
	$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[0..3]);
	if ($_[0]->{version} <= 79) {
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[4..5]);
	}
}
sub update_export {
	my $pack;
	if ($_[0]->{version} <= 72) {
		$pack = __PACKAGE__;
	} else {
		$pack = undef;
	}
	cse_alife_creature_abstract::update_export(@_);
	$_[1]->export_properties($pack, $_[0], (upd_properties_info)[0..3]);
	if ($_[0]->{version} <= 79) {
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[4..5]);
	}
}
#######################################################################
package cse_alife_psy_dog_phantom;
use strict;
sub init {
	cse_alife_monster_base::init(@_);
}
sub state_read {
	cse_alife_monster_base::state_read(@_);
}
sub state_write {
	cse_alife_monster_base::state_write(@_);
}
sub state_import {
	cse_alife_monster_base::state_import(@_);
}
sub state_export {
	cse_alife_monster_base::state_export(@_);
}
sub update_read {
	cse_alife_monster_base::update_read(@_);
}
sub update_write {
	cse_alife_monster_base::update_write(@_);
}
sub update_import {
	cse_alife_monster_base::update_import(@_);
}
sub update_export {
	cse_alife_monster_base::update_export(@_);
}
#######################################################################
package cse_alife_monster_rat;
use strict;
use constant properties_info => (
	{ name => 'field_of_view',			type => 'f32', default => 120.0 },
	{ name => 'eye_range',				type => 'f32', default => 10.0 },
	{ name => 'minimum_speed',			type => 'f32', default => 0.5 },
	{ name => 'maximum_speed',			type => 'f32', default => 1.5 },
	{ name => 'attack_speed',			type => 'f32', default => 4.0 },
	{ name => 'pursiut_distance',		type => 'f32', default => 100.0 },
	{ name => 'home_distance',			type => 'f32', default => 10.0 },
	{ name => 'success_attack_quant',	type => 'f32', default => 20.0 },
	{ name => 'death_quant',			type => 'f32', default => -10.0 },
	{ name => 'fear_quant',				type => 'f32', default => -20.0 },
	{ name => 'restore_quant',			type => 'f32', default => 10.0 },
	{ name => 'restore_time_interval',	type => 'u16', default => 3000 },
	{ name => 'minimum_value',			type => 'f32', default => 0.0 },
	{ name => 'maximum_value',			type => 'f32', default => 100.0 },
	{ name => 'normal_value',			type => 'f32', default => 66.0 },
	{ name => 'hit_power',				type => 'f32', default => 10.0 },
	{ name => 'hit_interval',			type => 'u16', default => 1500 },
	{ name => 'distance',				type => 'f32', default => 0.7 },
	{ name => 'maximum_angle',			type => 'f32', default => 45.0 },
	{ name => 'success_probability',	type => 'f32', default => 0.5 },
	{ name => 'cse_alife_monster_rat__unk1_f32',	type => 'f32', default => 5.0 },
);
sub init {
	cse_alife_monster_abstract::init(@_);
	cse_alife_inventory_item::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_monster_abstract::state_read(@_);
	$_[1]->unpack_properties($_[0], (properties_info)[0..1]);
	if ($_[0]->{version} < 7) {
		$_[1]->unpack_properties($_[0], (properties_info)[20]);
	}
	$_[1]->unpack_properties($_[0], (properties_info)[2..19]);
	if ($_[0]->{version} > 39) {
		cse_alife_inventory_item::state_read(@_);
	}
}
sub state_write {
	cse_alife_monster_abstract::state_write(@_);
	$_[1]->pack_properties($_[0], (properties_info)[0..1]);
	if ($_[0]->{version} < 7) {
		$_[1]->pack_properties($_[0], (properties_info)[20]);
	}
	$_[1]->pack_properties($_[0], (properties_info)[2..19]);
	if ($_[0]->{version} > 39) {
		cse_alife_inventory_item::state_write(@_);
	}
}
sub state_import {
	cse_alife_monster_abstract::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], (properties_info)[0..1]);
	if ($_[0]->{version} < 7) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[20]);
	}
	$_[1]->import_properties($_[2], $_[0], (properties_info)[2..19]);
	if ($_[0]->{version} > 39) {
		cse_alife_inventory_item::state_import(@_);
	}
}
sub state_export {
	cse_alife_monster_abstract::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0..1]);
	if ($_[0]->{version} < 7) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[20]);
	}
	$_[1]->export_properties(undef, $_[0], (properties_info)[2..19]);
	if ($_[0]->{version} > 39) {
		cse_alife_inventory_item::state_export(@_);
	}
}
sub update_read {
	cse_alife_monster_abstract::update_read(@_);
	if ($_[0]->{version} > 39) {
		cse_alife_inventory_item::update_read(@_);
	}
}
sub update_write {
	cse_alife_monster_abstract::update_write(@_);
	if ($_[0]->{version} > 39) {
		cse_alife_inventory_item::update_write(@_);
	}
}
sub update_import {
	cse_alife_monster_abstract::update_import(@_);
	if ($_[0]->{version} > 39) {
		cse_alife_inventory_item::update_import(@_);
	}
}
sub update_export {
	cse_alife_monster_abstract::update_export(@_);
	if ($_[0]->{version} > 39) {
		cse_alife_inventory_item::update_export(@_);
	}
}
#######################################################################
package cse_alife_rat_group; 
use strict;
use constant properties_info => (
	{ name => 'cse_alife_rat_group__unk_1_u32',		type => 'u32', default => 1 },
	{ name => 'alife_count',						type => 'u16', default => 5 },
	{ name => 'cse_alife_rat_group__unk_2_l32u16v',	type => 'l32u16v', default => [] },
);
use constant upd_properties_info => (
	{ name => 'upd:alife_count',		type => 'u32', default => 1 },
);
sub init {
	cse_alife_monster_rat::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
	stkutils::file::entity::init_properties($_[0], upd_properties_info);
}
sub state_read {
	cse_alife_monster_rat::state_read(@_);
	$_[1]->unpack_properties($_[0], (properties_info)[0..1]);
	if ($_[0]->{version} > 16) {
		$_[1]->unpack_properties($_[0], (properties_info)[2]);
	}
}
sub state_write {
	cse_alife_monster_rat::state_write(@_);
	$_[1]->pack_properties($_[0], (properties_info)[0..1]);
	if ($_[0]->{version} > 16) {
		$_[1]->pack_properties($_[0], (properties_info)[2]);
	}
}
sub state_import {
	cse_alife_monster_rat::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], (properties_info)[0..1]);
	if ($_[0]->{version} > 16) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[2]);
	}
}
sub state_export {
	cse_alife_monster_rat::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0..1]);
	if ($_[0]->{version} > 16) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[2]);
	}
}
sub update_read {
	cse_alife_monster_rat::update_read(@_);
	$_[1]->unpack_properties($_[0], upd_properties_info);	
}
sub update_write {
	cse_alife_monster_rat::update_write(@_);
	$_[1]->pack_properties( $_[0], upd_properties_info);	
}
sub update_import {
	cse_alife_monster_rat::update_import(@_);
	$_[1]->import_properties($_[2], $_[0],upd_properties_info);	
}
sub update_export {
	cse_alife_monster_rat::update_export(@_);
	$_[1]->export_properties(undef, $_[0], upd_properties_info);	
}
#######################################################################
package cse_alife_monster_base;
use strict;
use constant properties_info => (
	{ name => 'spec_object_id', type => 'u16', default => 65535 },
);
sub init {
	cse_alife_monster_abstract::init(@_);
	cse_ph_skeleton::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_monster_abstract::state_read(@_);
	if ($_[0]->{version} >= 68) {
		cse_ph_skeleton::state_read(@_);
	}
	if ($_[0]->{version} >= 109) {
		$_[1]->unpack_properties($_[0], properties_info);
	}
}
sub state_write {
	cse_alife_monster_abstract::state_write(@_);
	if ($_[0]->{version} >= 68) {
		cse_ph_skeleton::state_write(@_);
	}
	if ($_[0]->{version} >= 109) {
		$_[1]->pack_properties($_[0], properties_info);
	}
}
sub state_import {
	cse_alife_monster_abstract::state_import(@_);
	if ($_[0]->{version} >= 68) {
		cse_ph_skeleton::state_import(@_);
	}
	if ($_[0]->{version} >= 109) {
		$_[1]->import_properties($_[2], $_[0], properties_info);
	}
}
sub state_export {
	cse_alife_monster_abstract::state_export(@_);
	if ($_[0]->{version} >= 68) {
		cse_ph_skeleton::state_export(@_);
	}
	if ($_[0]->{version} >= 109) {
		$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
	}
}
sub update_read {
	cse_alife_monster_abstract::update_read(@_);
}
sub update_write {
	cse_alife_monster_abstract::update_write(@_);
}
sub update_import {
	cse_alife_monster_abstract::update_import(@_);
}
sub update_export {
	cse_alife_monster_abstract::update_export(@_);
}
#######################################################################
package cse_alife_monster_zombie;
use strict;
use constant properties_info => (
	{ name => 'field_of_view',	type => 'f32',	default => 0.0 },
	{ name => 'eye_range',		type => 'f32',	default => 0.0 },
	{ name => 'health',	type => 'f32',	default => 1.0 },
	{ name => 'minimum_speed',	type => 'f32',	default => 0.0 },
	{ name => 'maximum_speed',	type => 'f32',	default => 0.0 },
	{ name => 'attack_speed',	type => 'f32',	default => 0.0 },
	{ name => 'pursuit_distance',	type => 'f32',	default => 0.0 },
	{ name => 'home_distance',	type => 'f32',	default => 0.0 },
	{ name => 'hit_power',		type => 'f32',	default => 0.0 },
	{ name => 'hit_interval',	type => 'u16',	default => 0 },	
	{ name => 'distance',		type => 'f32',	default => 0.0 },
	{ name => 'maximum_angle',	type => 'f32',	default => 0.0 },
);
sub init {
	cse_alife_monster_abstract::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_monster_abstract::state_read(@_);
	$_[1]->unpack_properties($_[0], (properties_info)[0..1]);
	if ($_[0]->{version} <= 5) {
		$_[1]->unpack_properties($_[0], (properties_info)[2]);
	}
	$_[1]->unpack_properties($_[0], (properties_info)[3..11]);
}
sub state_write {
	cse_alife_monster_abstract::state_write(@_);
	$_[1]->pack_properties($_[0], (properties_info)[0..1]);
	if ($_[0]->{version} <= 5) {
		$_[1]->pack_properties($_[0], (properties_info)[2]);
	}
	$_[1]->pack_properties($_[0], (properties_info)[3..11]);
}
sub state_import {
	cse_alife_monster_abstract::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], (properties_info)[0..1]);
	if ($_[0]->{version} <= 5) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[2]);
	}
	$_[1]->import_properties($_[2], $_[0], (properties_info)[3..11]);
}
sub state_export {
	cse_alife_monster_abstract::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0..1]);
	if ($_[0]->{version} <= 5) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[2]);
	}
	$_[1]->export_properties(undef, $_[0], (properties_info)[3..11]);
}
sub update_read {
	cse_alife_monster_abstract::update_read(@_);
}
sub update_write {
	cse_alife_monster_abstract::update_write(@_);
}
sub update_import {
	cse_alife_monster_abstract::update_import(@_);
}
sub update_export {
	cse_alife_monster_abstract::update_export(@_);
}
#######################################################################
package cse_alife_flesh_group;
use strict;
use constant properties_info => (
	{ name => 'cse_alife_flash_group__unk_1_u32',		type => 'u32', default => 0 },
	{ name => 'alife_count',						type => 'u16', default => 0 },
	{ name => 'cse_alife_flash_group__unk_2_l32u16v',	type => 'l32u16v', default => [] },
);
use constant upd_properties_info => (
	{ name => 'upd:alife_count',	type => 'u32', default => 1 },
);
sub init {
	cse_alife_monster_base::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
	stkutils::file::entity::init_properties($_[0], upd_properties_info);
}
sub state_read {
	cse_alife_monster_base::state_read(@_);
	$_[1]->unpack_properties($_[0], properties_info);
}
sub state_write {
	cse_alife_monster_base::state_write(@_);
	$_[1]->pack_properties($_[0], properties_info);
}
sub state_import {
	cse_alife_monster_base::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub state_export {
	cse_alife_monster_base::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
}
sub update_read {
	cse_alife_monster_base::update_read(@_);
	$_[1]->unpack_properties($_[0], upd_properties_info);
}
sub update_write {
	cse_alife_monster_base::update_write(@_);
	$_[1]->pack_properties($_[0], upd_properties_info);
}
sub update_import {
	cse_alife_monster_base::update_import(@_);
	$_[1]->import_properties($_[2], $_[0], upd_properties_info);
}
sub update_export {
	cse_alife_monster_base::update_export(@_);
	$_[1]->export_properties(undef, $_[0], upd_properties_info);
}
#######################################################################
package cse_alife_trader_abstract;
use strict;
use constant eTraderFlagInfiniteAmmo	=> 0x00000001;
use constant eTraderFlagDummy		=> 0x00000000;	# really???
use constant properties_info => (
	{ name => 'cse_alife_trader_abstract__unk1_u32',	type => 'u32',	default => 0 },
	{ name => 'money',		type => 'u32',	default => 0 },
	{ name => 'specific_character',	type => 'sz',	default => '' },
	{ name => 'trader_flags',	type => 'h32',	default => 0x1 },
	{ name => 'character_profile',	type => 'sz',	default => '' },
	{ name => 'community_index',	type => 'u32',	default => 4294967295 },
	{ name => 'rank',		type => 'u32',	default => 2147483649 },
	{ name => 'reputation',		type => 'u32',	default => 2147483649 },
	{ name => 'character_name',	type => 'sz',	default => '' },
	{ name => 'cse_alife_trader_abstract__unk2_u8',	type => 'u8',	default => 0 },
	{ name => 'cse_alife_trader_abstract__unk3_u8',	type => 'u8',	default => 0 },
	{ name => 'cse_alife_trader_abstract__unk4_u32',	type => 'u32',	default => 0 },
	{ name => 'cse_alife_trader_abstract__unk5_u32',	type => 'u32',	default => 0 },
	{ name => 'cse_alife_trader_abstract__unk6_u32',	type => 'u32',	default => 0 },
);
use constant upd_properties_info => (
	{ name => 'upd:cse_alife_trader_abstract__unk1_u32',	type => 'u32',	default => 0 },
	{ name => 'upd:money',		type => 'u32',	default => 0 },
	{ name => 'upd:cse_trader_abstract__unk2_u32',	type => 'u32',	default => 1 },
);
sub init {
	stkutils::file::entity::init_properties($_[0], properties_info);
	stkutils::file::entity::init_properties($_[0], upd_properties_info);
}
sub state_read {
	if ($_[0]->{version} > 19) {
		if ($_[0]->{version} < 108) {
			$_[1]->unpack_properties($_[0], (properties_info)[0]);
		}
		if ($_[0]->{version} < 36) {
			$_[1]->unpack_properties($_[0], (properties_info)[13]);
		}
		if ($_[0]->{version} > 62) {
			$_[1]->unpack_properties($_[0], (properties_info)[1]);
		}
		if ($_[0]->{version} > 95) {
			$_[1]->unpack_properties($_[0], (properties_info)[2]);
		}
		if (($_[0]->{version} > 75) && ($_[0]->{version} <= 95)) {
			$_[1]->unpack_properties($_[0], (properties_info)[11]);
			if ($_[0]->{version} > 79) {
				$_[1]->unpack_properties($_[0], (properties_info)[12]);
			}
		}
		if ($_[0]->{version} > 77) {
			$_[1]->unpack_properties($_[0], (properties_info)[3]);
		}
		if ($_[0]->{version} > 95) {
			$_[1]->unpack_properties($_[0], (properties_info)[4]);
		}
		if ($_[0]->{version} > 85) {
			$_[1]->unpack_properties($_[0], (properties_info)[5]);
		}
		if ($_[0]->{version} > 86) {
			$_[1]->unpack_properties($_[0], (properties_info)[6..7]);
		}
		if ($_[0]->{version} > 104) {
			$_[1]->unpack_properties($_[0], (properties_info)[8]);
		}
		if ($_[0]->{version} >= 128) {
			$_[1]->unpack_properties($_[0], (properties_info)[9..10]);
		}
	}
}
sub state_write {
	if ($_[0]->{version} > 19) {
		if ($_[0]->{version} < 108) {
			$_[1]->pack_properties($_[0], (properties_info)[0]);
		}
		if ($_[0]->{version} < 36) {
			$_[1]->pack_properties($_[0], (properties_info)[13]);
		}
		if ($_[0]->{version} > 62) {
			$_[1]->pack_properties($_[0], (properties_info)[1]);
		}
		if ($_[0]->{version} > 94) {
			$_[1]->pack_properties($_[0], (properties_info)[2]);
		}
		if (($_[0]->{version} > 75) && ($_[0]->{version} <= 95)) {
			$_[1]->pack_properties($_[0], (properties_info)[11]);
			if ($_[0]->{version} > 79) {
				$_[1]->pack_properties($_[0], (properties_info)[12]);
			}
		}
		if ($_[0]->{version} > 77) {
			$_[1]->pack_properties($_[0], (properties_info)[3]);
		}
		if ($_[0]->{version} > 95) {
			$_[1]->pack_properties($_[0], (properties_info)[4]);
		}
		if ($_[0]->{version} > 85) {
			$_[1]->pack_properties($_[0], (properties_info)[5]);
		}
		if ($_[0]->{version} > 86) {
			$_[1]->pack_properties($_[0], (properties_info)[6..7]);
		}
		if ($_[0]->{version} > 104) {
			$_[1]->pack_properties($_[0], (properties_info)[8]);
		}
		if ($_[0]->{version} >= 128) {
			$_[1]->pack_properties($_[0], (properties_info)[9..10]);
		}
	}
}
sub state_import {	
	if ($_[0]->{version} > 19) {
		if ($_[0]->{version} < 108) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[0]);
		}
		if ($_[0]->{version} < 36) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[13]);
		}
		if ($_[0]->{version} > 62) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[1]);
		}
		if ($_[0]->{version} > 95) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[2]);
		}
		if (($_[0]->{version} > 75) && ($_[0]->{version} <= 95)) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[11]);
			if ($_[0]->{version} > 79) {
				$_[1]->import_properties($_[2], $_[0], (properties_info)[12]);
			}
		}
		if ($_[0]->{version} > 77) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[3]);
		}
		if ($_[0]->{version} > 95) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[4]);
		}
		if ($_[0]->{version} > 85) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[5]);
		}
		if ($_[0]->{version} > 86) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[6..7]);
		}
		if ($_[0]->{version} > 104) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[8]);
		}
		if ($_[0]->{version} >= 128) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[9..10]);
		}
	}
}
sub state_export {
	if ($_[0]->{version} > 19) {
		if ($_[0]->{version} < 108) {
			$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0]);
		}
		if ($_[0]->{version} < 36) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[13]);
		}
		if ($_[0]->{version} > 62) {
			my $pack;
			if ($_[0]->{version} > 108) {
				$pack = __PACKAGE__;
			} else {
				$pack = undef;
			}
			$_[1]->export_properties($pack, $_[0], (properties_info)[1]);
		}
		if ($_[0]->{version} > 95) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[2]);
		}
		if (($_[0]->{version} > 75) && ($_[0]->{version} <= 95)) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[11]);
			if ($_[0]->{version} > 79) {
				$_[1]->export_properties(undef, $_[0], (properties_info)[12]);
			}
		}
		if ($_[0]->{version} > 77) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[3]);
		}
		if ($_[0]->{version} > 95) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[4]);
		}
		if ($_[0]->{version} > 85) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[5]);
		}
		if ($_[0]->{version} > 86) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[6..7]);
		}
		if ($_[0]->{version} > 104) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[8]);
		}
		if ($_[0]->{version} >= 128) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[9..10]);
		}
	}
}
sub update_read {
	if (($_[0]->{version} > 19) && ($_[0]->{version} < 102)) {
		$_[1]->unpack_properties($_[0], (upd_properties_info)[0..1]);
		if ($_[0]->{version} < 86) {
			$_[1]->unpack_properties($_[0], (upd_properties_info)[2]);
		}
	}
}
sub update_write {
	if (($_[0]->{version} > 19) && ($_[0]->{version} < 102)) {
		$_[1]->pack_properties($_[0], (upd_properties_info)[0..1]);
		if ($_[0]->{version} < 86) {
			$_[1]->pack_properties($_[0], (upd_properties_info)[2]);
		}
	}
}
sub update_import {	
	if (($_[0]->{version} > 19) && ($_[0]->{version} < 102)) {
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[0..1]);
		if ($_[0]->{version} < 86) {
			$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[2]);
		}
	}
}
sub update_export {	
	if (($_[0]->{version} > 19) && ($_[0]->{version} < 102)) {
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[0..1]);
		if ($_[0]->{version} < 86) {
			$_[1]->export_properties(undef, $_[0], (upd_properties_info)[2]);
		}
	}
}
#######################################################################
package cse_alife_trader;
use strict;
use constant properties_info => (
	{ name => 'organization_id',			type => 'u32',	default => 1 },
	{ name => 'ordered_artefacts',	type => 'ordaf',	default => [] },
	{ name => 'supplies',		type => 'supplies',	default => [] },
);
sub init {
	cse_alife_dynamic_object_visual::init(@_);
	cse_alife_trader_abstract::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_dynamic_object_visual::state_read(@_);
	cse_alife_trader_abstract::state_read(@_);
	if ($_[0]->{version} < 118) {
		if ($_[0]->{version} > 35) {
			$_[1]->unpack_properties($_[0], (properties_info)[0]);
		}
		if ($_[0]->{version} > 29) {
			$_[1]->unpack_properties($_[0], (properties_info)[1]);
		}
		if ($_[0]->{version} > 30) {
			$_[1]->unpack_properties($_[0], (properties_info)[2]);
		}
	}
}
sub state_write {
	cse_alife_dynamic_object_visual::state_write(@_);
	cse_alife_trader_abstract::state_write(@_);
	if ($_[0]->{version} < 118) {
		if ($_[0]->{version} > 35) {
			$_[1]->pack_properties($_[0], (properties_info)[0]);
		}
		if ($_[0]->{version} > 29) {
			$_[1]->pack_properties($_[0], (properties_info)[1]);
		}
		if ($_[0]->{version} > 30) {
			$_[1]->pack_properties($_[0], (properties_info)[2]);
		}
	}
}
sub state_import {
	cse_alife_dynamic_object_visual::state_import(@_);
	cse_alife_trader_abstract::state_import(@_);
	if ($_[0]->{version} < 118) {
		if ($_[0]->{version} > 35) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[0]);
		}
		if ($_[0]->{version} > 29) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[1]);
		}
		if ($_[0]->{version} > 30) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[2]);
		}
	}
}
sub state_export {
	cse_alife_dynamic_object_visual::state_export(@_);
	cse_alife_trader_abstract::state_export(@_);
	if ($_[0]->{version} < 118) {
		if ($_[0]->{version} > 35) {
			$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0]);
		}
		if ($_[0]->{version} > 29) {
			my $pack;
			if ($_[0]->{version} <= 35) {
				$pack = __PACKAGE__;
			} else {
				$pack = undef;
			}
			$_[1]->export_properties($pack, $_[0], (properties_info)[1]);
		}
		if ($_[0]->{version} > 30) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[2]);
		}
	}
}
sub update_read {
	cse_alife_trader_abstract::update_read(@_);
}
sub update_write {
	cse_alife_trader_abstract::update_write(@_);
}
sub update_import {
	cse_alife_trader_abstract::update_import(@_);
}
sub update_export {
	cse_alife_trader_abstract::update_export(@_);
}
#######################################################################
package cse_alife_human_abstract;
use strict;
use constant properties_info => (
	{ name => 'path',	type => 'l32u32v',	default => [] },
	{ name => 'visited_vertices',	type => 'u32', 		default => 0 },
	{ name => 'known_customers_sz',		type => 'sz', default => '' },
	{ name => 'known_customers',	type => 'l32u32v', default => [] },
	{ name => 'equipment_preferences',	type => 'l32u8v', default => [] },
	{ name => 'main_weapon_preferences',	type => 'l32u8v', default => [] },
	{ name => 'smart_terrain_id',	type => 'u16', default => 0 },
	{ name => 'cse_alife_human_abstract__unk1_u32',	type => 'ha1', 		default => [] },
	{ name => 'cse_alife_human_abstract__unk2_u32',	type => 'ha2', 		default => [] },
	{ name => 'cse_alife_human_abstract__unk3_u32',	type => 'u32', 		default => 0 },
);
use constant upd_properties_info => (
	{ name => 'upd:cse_alife_human_abstract__unk3_u32',	type => 'u32', 		default => 0 },
	{ name => 'upd:cse_alife_human_abstract__unk4_u32',	type => 'u32', 		default => 0xffffffff },
	{ name => 'upd:cse_alife_human_abstract__unk5_u32',	type => 'u32', 		default => 0xffffffff },
);
sub init {
	cse_alife_monster_abstract::init(@_);
	cse_alife_trader_abstract::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
	stkutils::file::entity::init_properties($_[0], upd_properties_info);
}
sub state_read {
	cse_alife_trader_abstract::state_read(@_);
	cse_alife_monster_abstract::state_read(@_);
	if ($_[0]->{version} > 19) {
		if ($_[0]->{version} < 110) {
			$_[1]->unpack_properties($_[0], (properties_info)[0..1]);
		}
		if ($_[0]->{version} > 35) {
			if ($_[0]->{version} < 110) {
				$_[1]->unpack_properties($_[0], (properties_info)[2]);
			}
			if ($_[0]->{version} < 118) {
				$_[1]->unpack_properties($_[0], (properties_info)[3]);
			}
		} else {
			$_[1]->unpack_properties($_[0], (properties_info)[9]);
		}
		if ($_[0]->{version} > 63) {
			$_[1]->unpack_properties($_[0], (properties_info)[4..5]);
		} elsif (($_[0]->{version} > 37) && ($_[0]->{version} <= 63)) {
			$_[1]->unpack_properties($_[0], (properties_info)[7..8]);
		}
	}
	if (($_[0]->{version} >= 110) && ($_[0]->{version} < 112)) {
		$_[1]->unpack_properties($_[0], (properties_info)[6]);
	}
}
sub state_write {
	cse_alife_trader_abstract::state_write(@_);
	cse_alife_monster_abstract::state_write(@_);
	if ($_[0]->{version} > 19) {
		if ($_[0]->{version} < 110) {
			$_[1]->pack_properties($_[0], (properties_info)[0..1]);
		}
		if ($_[0]->{version} > 35) {
			if ($_[0]->{version} < 110) {
				$_[1]->pack_properties($_[0], (properties_info)[2]);
			}
			if ($_[0]->{version} < 118) {
				$_[1]->pack_properties($_[0], (properties_info)[3]);
			}
		} else {
			$_[1]->pack_properties($_[0], (properties_info)[9]);
		}
		if ($_[0]->{version} > 63) {
			$_[1]->pack_properties($_[0], (properties_info)[4..5]);
		} elsif (($_[0]->{version} > 37) && ($_[0]->{version} <= 63)) {
			$_[1]->pack_properties($_[0], (properties_info)[7..8]);
		}
	}
	if (($_[0]->{version} >= 110) && ($_[0]->{version} < 112)) {
		$_[1]->pack_properties($_[0], (properties_info)[6]);
	}
}
sub state_import {
	cse_alife_trader_abstract::state_import(@_);
	cse_alife_monster_abstract::state_import(@_);
	if ($_[0]->{version} > 19) {
		if ($_[0]->{version} < 110) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[0..1]);
		}
		if ($_[0]->{version} > 35) {
			if ($_[0]->{version} < 110) {
				$_[1]->import_properties($_[2], $_[0], (properties_info)[2]);
			}
			if ($_[0]->{version} < 118) {
				$_[1]->import_properties($_[2], $_[0], (properties_info)[3]);
			}
		} else {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[9]);
		}
		if ($_[0]->{version} > 63) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[4..5]);
		} elsif (($_[0]->{version} > 37) && ($_[0]->{version} <= 63)) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[7..8]);
		}
	}
	if (($_[0]->{version} >= 110) && ($_[0]->{version} < 112)) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[6]);
	}
}
sub state_export {
	cse_alife_trader_abstract::state_export(@_);
	cse_alife_monster_abstract::state_export(@_);
	if ($_[0]->{version} > 19) {
		if ($_[0]->{version} < 110) {
			$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0..1]);
		}
		if ($_[0]->{version} > 35) {
			if ($_[0]->{version} < 110) {
				$_[1]->export_properties(undef, $_[0], (properties_info)[2]);
			}
			if ($_[0]->{version} < 118) {
				$_[1]->export_properties(undef, $_[0], (properties_info)[3]);
			}
		}
		if ($_[0]->{version} > 63) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[4..5]);
		} elsif (($_[0]->{version} > 37) && ($_[0]->{version} <= 63)) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[7..8]);
		} else {
			$_[1]->export_properties(undef, $_[0], (properties_info)[9]);
		}
	}
	if (($_[0]->{version} >= 110) && ($_[0]->{version} < 112)) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[6]);
	}
}
sub update_read {
	cse_alife_trader_abstract::update_read(@_);
	cse_alife_monster_abstract::update_read(@_);
	if ($_[0]->{version} <= 109) {
		$_[1]->unpack_properties($_[0], upd_properties_info);
	}
}
sub update_write {
	cse_alife_trader_abstract::update_write(@_);
	cse_alife_monster_abstract::update_write(@_);
	if ($_[0]->{version} <= 109) {
		$_[1]->pack_properties($_[0], upd_properties_info);
	}
}
sub update_import {
	cse_alife_trader_abstract::update_import(@_);
	cse_alife_monster_abstract::update_import(@_);
	if ($_[0]->{version} <= 109) {
		$_[1]->import_properties($_[2], $_[0], upd_properties_info);
	}
}
sub update_export {
	cse_alife_trader_abstract::update_export(@_);
	cse_alife_monster_abstract::update_export(@_);
	if ($_[0]->{version} <= 109) {
		$_[1]->export_properties(undef, $_[0], upd_properties_info);
	}
}
#######################################################################
package cse_alife_object_idol; 
use strict;
use constant properties_info => (
	{ name => 'cse_alife_object_idol__unk1_sz',	type => 'sz',	default => '' },
	{ name => 'cse_alife_object_idol__unk2_u32',	type => 'u32',	default => 0 },
);
sub init {
	cse_alife_human_abstract::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_human_abstract::state_read(@_);
	$_[1]->unpack_properties($_[0], properties_info);
}
sub state_write {
	cse_alife_human_abstract::state_write(@_);
	$_[1]->pack_properties($_[0], properties_info);
}
sub state_import {
	cse_alife_human_abstract::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub state_export {
	cse_alife_human_abstract::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
}
sub update_read {
	cse_alife_human_abstract::update_read(@_);
}
sub update_write {
	cse_alife_human_abstract::update_write(@_);
}
sub update_import {
	cse_alife_human_abstract::update_import(@_);
}
sub update_export {
	cse_alife_human_abstract::update_export(@_);
}
#######################################################################
package cse_alife_human_stalker;
use strict;
use constant properties_info => (
	{ name => 'cse_alife_human_stalker__unk1_bool', type => 'u8', default => 0 },
);
use constant upd_properties_info => (
	{ name => 'upd:start_dialog', type => 'sz' },
);
sub init {
	cse_alife_human_abstract::init(@_);
	cse_ph_skeleton::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
	stkutils::file::entity::init_properties($_[0], upd_properties_info);
}
sub state_read {
	cse_alife_human_abstract::state_read(@_);
	if ($_[0]->{version} > 67) {
		cse_ph_skeleton::state_read(@_);
	}
	if (($_[0]->{version} > 90) && ($_[0]->{version} < 111)) {
		$_[1]->unpack_properties($_[0], properties_info);
	}
}
sub state_write {
	cse_alife_human_abstract::state_write(@_);
	if ($_[0]->{version} > 67) {
		cse_ph_skeleton::state_write(@_);
	}
	if (($_[0]->{version} > 90) && ($_[0]->{version} < 111)) {
		$_[1]->pack_properties($_[0], properties_info);
	}
}
sub state_import {
	cse_alife_human_abstract::state_import(@_);
	if ($_[0]->{version} > 67) {
		cse_ph_skeleton::state_import(@_);
	}
	if (($_[0]->{version} > 90) && ($_[0]->{version} < 111)) {
		$_[1]->import_properties($_[2], $_[0], properties_info);
	}
}
sub state_export {
	cse_alife_human_abstract::state_export(@_);
	if ($_[0]->{version} > 67) {
		cse_ph_skeleton::state_export(@_);
	}
	if (($_[0]->{version} > 90) && ($_[0]->{version} < 111)) {
		$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
	}
}
sub update_read {
	cse_alife_human_abstract::update_read(@_);
	if ($_[0]->{version} > 94) {
		$_[1]->unpack_properties($_[0], upd_properties_info);
	}
}
sub update_write {
	cse_alife_human_abstract::update_write(@_);
	if ($_[0]->{version} > 94) {
		$_[1]->pack_properties($_[0], upd_properties_info);
	}
}
sub update_import {
	cse_alife_human_abstract::update_import(@_);
	if ($_[0]->{version} > 94) {
	$_[1]->import_properties($_[2], $_[0], upd_properties_info);
	}
}
sub update_export {
	cse_alife_human_abstract::update_export(@_);
	if ($_[0]->{version} > 94) {
	$_[1]->export_properties(__PACKAGE__, $_[0], upd_properties_info);
	}
}
#######################################################################
package cse_alife_creature_actor;
use strict;
use constant FL_HANDLED => 0x20;
use stkutils::debug qw(fail warn);
use constant properties_info => (
	{ name => 'holder_id', type => 'h16', default => 0xffff },
);
use constant upd_properties_info => (
	{ name => 'upd:actor_state',		type => 'h16', default => 0  },
	{ name => 'upd:actor_accel',		type => 'sdir', default => []  },
	{ name => 'upd:actor_velocity',		type => 'sdir', default => []  },
	{ name => 'upd:actor_radiation',	type => 'f32', default => 0  },
	{ name => 'upd:actor_radiation',	type => 'q16', default => 0  },
	{ name => 'upd:cse_alife_creature_actor_unk1_q16',	type => 'q16', default => 0  },
	{ name => 'upd:actor_weapon',		type => 'u8', default => 0  },
	{ name => 'upd:num_items',		type => 'u16', default => 0  },
	{ name => 'upd:actor_radiation',	type => 'q16_old', default => 0  },
#m_AliveState	
	{ name => 'upd:alive_state_enabled',		type => 'u8', default => 0  },
	{ name => 'upd:alive_state_angular_vel',	type => 'f32v3', default => []  },
	{ name => 'upd:alive_state_linear_vel',		type => 'f32v3', default => []  },
	{ name => 'upd:alive_state_force',			type => 'f32v3', default => []  },
	{ name => 'upd:alive_state_torque',			type => 'f32v3', default => []  },
	{ name => 'upd:alive_state_position',		type => 'f32v3', default => []  },
	{ name => 'upd:alive_state_quaternion',		type => 'f32v4', default => []  },
#m_DeadBodyData	
	{ name => 'upd:bone_data_size',	type => 'u8', default => 0  },
);
sub init {
	cse_alife_creature_abstract::init(@_);
	cse_alife_trader_abstract::init(@_);
	cse_ph_skeleton::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
	stkutils::file::entity::init_properties($_[0], upd_properties_info);
}
sub state_read {
	cse_alife_creature_abstract::state_read(@_);
	cse_alife_trader_abstract::state_read(@_);
	if ($_[0]->{version} > 91) {
		cse_ph_skeleton::state_read(@_);
	}
	if ($_[0]->{version} > 88) {
		$_[1]->unpack_properties($_[0], properties_info);
	}
}
sub state_write {
	cse_alife_creature_abstract::state_write(@_);
	cse_alife_trader_abstract::state_write(@_);
	if ($_[0]->{version} > 91) {
		cse_ph_skeleton::state_write(@_);
	}
	if ($_[0]->{version} > 88) {
		$_[1]->pack_properties($_[0], properties_info);
	}
}
sub state_import {
	cse_alife_creature_abstract::state_import(@_);
	cse_alife_trader_abstract::state_import(@_);
	if ($_[0]->{version} > 91) {
		cse_ph_skeleton::state_import(@_);
	}
	if ($_[0]->{version} > 88) {
		$_[1]->import_properties($_[2], $_[0], properties_info);
	}
}
sub state_export {
	cse_alife_creature_abstract::state_export(@_);
	cse_alife_trader_abstract::state_export(@_);
	if ($_[0]->{version} > 91) {
		cse_ph_skeleton::state_export(@_);
	}
	if ($_[0]->{version} > 88) {
		$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
	}
}
sub update_read {
	cse_alife_creature_abstract::update_read(@_);
	cse_alife_trader_abstract::update_read(@_);
	$_[1]->unpack_properties($_[0], (upd_properties_info)[0..2]);
	return if UNIVERSAL::can($_[0], 'is_handled') && $_[0]->is_handled();
	if ($_[0]->{version} > 109) {
		$_[1]->unpack_properties($_[0], (upd_properties_info)[3]);
	} elsif ($_[0]->{version} > 40) {
		$_[1]->unpack_properties($_[0], (upd_properties_info)[4]);
	} else {
		$_[1]->unpack_properties($_[0], (upd_properties_info)[8]);
	}
	if (($_[0]->{version} > 101) && ($_[0]->{version} <= 104)) {
		$_[1]->unpack_properties($_[0], (upd_properties_info)[5]);
	}
	$_[1]->unpack_properties($_[0], (upd_properties_info)[6]);
	if ($_[0]->{version} > 39) {
		$_[1]->unpack_properties($_[0], (upd_properties_info)[7]);
	}
	if (defined $_[0]->{'upd:num_items'}) {
		if ($_[0]->{'upd:num_items'} == 0) {
			return;
		} elsif ($_[0]->{'upd:num_items'} == 1) {
			$_[1]->unpack_properties($_[0], (upd_properties_info)[9..15]);
		} else {
			$_[1]->unpack_properties($_[0], (upd_properties_info)[16]);
			my $length = $_[0]->{'upd:num_items'} * $_[0]->{'upd:bone_data_size'} + 24;
			$_[0]->{'upd:dead_body_data'} = $_[1]->unpack("a[$length]", $length);
		}
	}
}
sub update_write {
	cse_alife_creature_abstract::update_write(@_);
	cse_alife_trader_abstract::update_write(@_);
	$_[1]->pack_properties($_[0], (upd_properties_info)[0..2]);
	if ($_[0]->{version} > 109) {
		$_[1]->pack_properties($_[0], (upd_properties_info)[3]);
	} elsif ($_[0]->{version} > 40) {
		$_[1]->pack_properties($_[0], (upd_properties_info)[4]);
	} else {
		$_[1]->pack_properties($_[0], (upd_properties_info)[8]);
	}
	if (($_[0]->{version} > 101) && ($_[0]->{version} <= 104)) {
		$_[1]->pack_properties($_[0], (upd_properties_info)[5]);
	}
	$_[1]->pack_properties($_[0], (upd_properties_info)[6]);
	if ($_[0]->{version} > 39) {
		$_[1]->pack_properties($_[0], (upd_properties_info)[7]);
	}
	if ($_[0]->{'upd:num_items'} == 0) {
		return;
	} elsif ($_[0]->{'upd:num_items'} == 1) {
		$_[1]->pack_properties($_[0], (upd_properties_info)[9..15]);
	} else {
		$_[1]->pack_properties($_[0], (upd_properties_info)[16]);
		my $length = $_[0]->{'upd:num_items'} * $_[0]->{'upd:bone_data_size'} + 24;
		$_[0]->{'upd:dead_body_data'} = $_[1]->pack("a[$length]");
	}
}
sub update_import {
	cse_alife_creature_abstract::update_import(@_);
	cse_alife_trader_abstract::update_import(@_);
	$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[0..2]);
	if ($_[0]->{version} > 109) {
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[3]);
	} elsif ($_[0]->{version} > 40) {
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[4]);
	} else {
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[8]);
	}
	if (($_[0]->{version} > 101) && ($_[0]->{version} <= 104)) {
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[5]);
	}
	$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[6]);
	if ($_[0]->{version} > 39) {
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[7]);
	}
	if ($_[0]->{'upd:num_items'} == 0) {
		return;
	} elsif ($_[0]->{'upd:num_items'} == 1) {
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[9..15]);
	} else {
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[16]);
		$_[0]->{'upd:dead_body_data'} = $_[1]->value($_[2], 'upd:dead_body_data');
	}
}
sub update_export {
	cse_alife_creature_abstract::update_export(@_);
	cse_alife_trader_abstract::update_export(@_);
	my $pack;
	if (($_[0]->{version} >= 21) && ($_[0]->{version} <= 88)) {
		$pack = __PACKAGE__;
	} else {
		$pack = undef;
	}
	$_[1]->export_properties($pack, $_[0], (upd_properties_info)[0..2]);
	if ($_[0]->{version} > 109) {
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[3]);
	} elsif ($_[0]->{version} > 40) {
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[4]);
	} else {
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[8]);
	}
	if (($_[0]->{version} > 101) && ($_[0]->{version} <= 104)) {
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[5]);
	}
	$_[1]->export_properties(undef, $_[0], (upd_properties_info)[6]);
	if ($_[0]->{version} > 39) {
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[7]);
	}
	if ($_[0]->{'upd:num_items'} == 0) {
		return;
	} elsif ($_[0]->{'upd:num_items'} == 1) {
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[9..15]);
	} else {
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[16]);
		my $fh = $_[1]->{fh};
		print $fh "upd:dead_body_data = $_[0]->{'upd:dead_body_data'}\n";
	}
}
sub is_handled {return ($_[0]->{flags} & FL_HANDLED)}
#######################################################################
package cse_smart_cover;
use strict;
use constant properties_info => (
	{ name => 'description',	type => 'sz',	default => '' },
	{ name => 'hold_position_time',	type => 'f32',	default => 0.0 },
	{ name => 'enter_min_enemy_distance',	type => 'f32',	default => 0.0 },
	{ name => 'exit_min_enemy_distance',	type => 'f32',	default => 0.0 },
	{ name => 'is_combat_cover',		type => 'u8',	default => 0 },
	{ name => 'MP_respawn',	type => 'u8',	default => 0 },
);
sub init {
	cse_alife_dynamic_object::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_dynamic_object::state_read(@_);
	cse_shape::state_read(@_);
	$_[1]->unpack_properties($_[0], (properties_info)[0..1]);
	if ($_[0]->{version} >= 120) {
		$_[1]->unpack_properties($_[0], (properties_info)[2..3]);
	}
	if ($_[0]->{version} >= 122) {
		$_[1]->unpack_properties($_[0], (properties_info)[4]);
	}
	if ($_[0]->{version} >= 128) {
		$_[1]->unpack_properties($_[0], (properties_info)[5]);
	}
}
sub state_write {
	cse_alife_dynamic_object::state_write(@_);
	cse_shape::state_write(@_);
	$_[1]->pack_properties($_[0], (properties_info)[0..1]);
	if ($_[0]->{version} >= 120) {
		$_[1]->pack_properties($_[0], (properties_info)[2..3]);
	}
	if ($_[0]->{version} >= 122) {
		$_[1]->pack_properties($_[0], (properties_info)[4]);
	}
	if ($_[0]->{version} >= 128) {
		$_[1]->pack_properties($_[0], (properties_info)[5]);
	}
}
sub state_import {
	cse_alife_dynamic_object::state_import(@_);
	cse_shape::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], (properties_info)[0..1]);
	if ($_[0]->{version} >= 120) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[2..3]);
	}
	if ($_[0]->{version} >= 122) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[4]);
	}
	if ($_[0]->{version} >= 128) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[5]);
	}
}
sub state_export {
	cse_alife_dynamic_object::state_export(@_);
	cse_shape::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0..1]);
	if ($_[0]->{version} >= 120) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[2..3]);
	}
	if ($_[0]->{version} >= 122) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[4]);
	}
	if ($_[0]->{version} >= 128) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[5]);
	}
}
#######################################################################
package cse_alife_space_restrictor;
use constant eDefaultRestrictorTypeNone	=> 0x00;
use constant eDefaultRestrictorTypeOut	=> 0x01;
use constant eDefaultRestrictorTypeIn	=> 0x02;
use constant eRestrictorTypeNone	=> 0x03;
use constant eRestrictorTypeIn		=> 0x04;
use constant eRestrictorTypeOut		=> 0x05;
use strict;
use constant properties_info => (
	{ name => 'restrictor_type', type => 'u8', default => 0xff },
);
sub init {
	cse_alife_object::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	if ($_[0]->{version} > 14) {
		cse_alife_object::state_read(@_);
	}
	cse_shape::state_read(@_);
	if ($_[0]->{version} > 74) {
		$_[1]->unpack_properties($_[0], properties_info);
	}
}
sub state_write {
	if ($_[0]->{version} > 14) {
	cse_alife_object::state_write(@_);
	}
	cse_shape::state_write(@_);
	if ($_[0]->{version} > 74) {
		$_[1]->pack_properties($_[0], properties_info);
	}
}
sub state_import {
	if ($_[0]->{version} > 14) {
	cse_alife_object::state_import(@_);
	}
	cse_shape::state_import(@_);
	if ($_[0]->{version} > 74) {
		$_[1]->import_properties($_[2], $_[0], properties_info);
	}
}
sub state_export {
	if ($_[0]->{version} > 14) {
	cse_alife_object::state_export(@_);
	}
	cse_shape::state_export(@_);
	if ($_[0]->{version} > 74) {
		$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
	}
}
#######################################################################
package cse_alife_team_base_zone;
use strict;
use constant properties_info => (
	{ name => 'team', type => 'u8', default => 0 },
);
sub init {
	cse_alife_space_restrictor::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_space_restrictor::state_read(@_);
	$_[1]->unpack_properties($_[0], properties_info);
}
sub state_write {
	cse_alife_space_restrictor::state_write(@_);
	$_[1]->pack_properties($_[0], properties_info);
}
sub state_import {
	cse_alife_space_restrictor::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub state_export {
	cse_alife_space_restrictor::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
}
#######################################################################
package cse_alife_level_changer;
use strict;
use constant properties_info => (
	{ name => 'cse_alife_level_changer__unk1_s32',	type => 's32',	default => -1 },
	{ name => 'cse_alife_level_changer__unk2_s32',	type => 's32',	default => -1 },
	{ name => 'dest_game_vertex_id',	type => 'u16',	default => 0 },
	{ name => 'dest_level_vertex_id',	type => 'u32',	default => 0 },
	{ name => 'dest_position',		type => 'f32v3',default => [0,0,0] },
	{ name => 'dest_direction',		type => 'f32v3',default => [0,0,0] },
	{ name => 'angle_y',		type => 'f32',default => 0.0 },
	{ name => 'dest_level_name',		type => 'sz',	default => '' },
	{ name => 'dest_graph_point',		type => 'sz',	default => '' },
	{ name => 'silent_mode',		type => 'u8',	default => 0 },
);
sub init {
	cse_alife_space_restrictor::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_space_restrictor::state_read(@_);
	if ($_[0]->{version} < 34) {
		$_[1]->unpack_properties($_[0], (properties_info)[0..1]);
	} else {
		$_[1]->unpack_properties($_[0], (properties_info)[2..4]);
		if ($_[0]->{version} > 53) {
			$_[1]->unpack_properties($_[0], (properties_info)[5]);
		} else {
			$_[1]->unpack_properties($_[0], (properties_info)[6]);
		}
	}
	$_[1]->unpack_properties($_[0], (properties_info)[7..8]);
	if ($_[0]->{version} > 116) {
		$_[1]->unpack_properties($_[0], (properties_info)[9]);
	}
}
sub state_write {
	cse_alife_space_restrictor::state_write(@_);
	if ($_[0]->{version} < 34) {
		$_[1]->pack_properties($_[0], (properties_info)[0..1]);
	} else {
		$_[1]->pack_properties($_[0], (properties_info)[2..4]);
		if ($_[0]->{version} > 53) {
			$_[1]->pack_properties($_[0], (properties_info)[5]);
		} else {
			$_[1]->pack_properties($_[0], (properties_info)[6]);
		}
	}
	$_[1]->pack_properties($_[0], (properties_info)[7..8]);
	if ($_[0]->{version} > 116) {
		$_[1]->pack_properties($_[0], (properties_info)[9]);
	}
}
sub state_import {
	cse_alife_space_restrictor::state_import(@_);
	if ($_[0]->{version} < 34) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[0..1]);
	} else {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[2..4]);
		if ($_[0]->{version} > 53) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[5]);
		} else {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[6]);
		}
	}
	$_[1]->import_properties($_[2], $_[0], (properties_info)[7..8]);
	if ($_[0]->{version} > 116) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[9]);
	}
}
sub state_export {
	cse_alife_space_restrictor::state_export(@_);
	if ($_[0]->{version} < 34) {
		$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0..1]);
	} else {
		$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[2..4]);
		if ($_[0]->{version} > 53) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[5]);
		} else {
			$_[1]->export_properties(undef, $_[0], (properties_info)[6]);
		}
	}
	$_[1]->export_properties(undef, $_[0], (properties_info)[7..8]);
	if ($_[0]->{version} > 116) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[9]);
	}
}
#######################################################################
package cse_alife_smart_zone;
use strict;
sub init {
	cse_alife_space_restrictor::init(@_);
}
sub state_read {
	cse_alife_space_restrictor::state_read(@_);
}
sub state_write {
	cse_alife_space_restrictor::state_write(@_);
}
sub state_import {
	cse_alife_space_restrictor::state_import(@_);
}
sub state_export {
	cse_alife_space_restrictor::state_export(@_);
}
#######################################################################
package cse_alife_custom_zone;
use strict;
use constant FL_HANDLED => 0x20;
use constant properties_info => (
	{ name => 'max_power',		type => 'f32',	default => 0.0 },
	{ name => 'attenuation',		type => 'f32',	default => 0.0 },
	{ name => 'period',	type => 'u32',	default => 0 },	
	{ name => 'owner_id',		type => 'h32',	default => 0xffffffff },
	{ name => 'enabled_time',	type => 'u32',	default => 0 },
	{ name => 'disabled_time',	type => 'u32',	default => 0 },
	{ name => 'start_time_shift',	type => 'u32',	default => 0 },
);
use constant upd_properties_info => (
	{ name => 'upd:cse_alife_custom_zone__unk1_h32',		type => 'h32',	default => 0xffffffff },
);
sub init {
	cse_alife_space_restrictor::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
	stkutils::file::entity::init_properties($_[0], upd_properties_info);
}
sub state_read {
	cse_alife_space_restrictor::state_read(@_);
	$_[1]->unpack_properties($_[0], (properties_info)[0]);
	if ($_[0]->{version} < 113) {
		$_[1]->unpack_properties($_[0], (properties_info)[1..2]);
	}
	if (($_[0]->{version} > 66) && ($_[0]->{version} < 118)) {
		$_[1]->unpack_properties($_[0], (properties_info)[1]);
	}
	if ($_[0]->{version} > 102) {
		$_[1]->unpack_properties($_[0], (properties_info)[3]);
	}
	if ($_[0]->{version} > 105) {
		$_[1]->unpack_properties($_[0], (properties_info)[4..5]);
	}
	if ($_[0]->{version} > 106) {
		$_[1]->unpack_properties($_[0], (properties_info)[6]);
	}
}
sub state_write {
	cse_alife_space_restrictor::state_write(@_);
	$_[1]->pack_properties($_[0], (properties_info)[0]);
	if ($_[0]->{version} < 113) {
		$_[1]->pack_properties($_[0], (properties_info)[1..2]);
	}
	if (($_[0]->{version} > 66) && ($_[0]->{version} < 118)) {
		$_[1]->pack_properties($_[0], (properties_info)[1]);
	}
	if ($_[0]->{version} > 102) {
		$_[1]->pack_properties($_[0], (properties_info)[3]);
	}
	if ($_[0]->{version} > 105) {
		$_[1]->pack_properties($_[0], (properties_info)[4..5]);
	}
	if ($_[0]->{version} > 106) {
		$_[1]->pack_properties($_[0], (properties_info)[6]);
	}
}
sub state_import {
	cse_alife_space_restrictor::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], (properties_info)[0]);
	if ($_[0]->{version} < 113) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[1..2]);
	}
	if (($_[0]->{version} > 66) && ($_[0]->{version} < 118)) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[1]);
	}
	if ($_[0]->{version} > 102) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[3]);
	}
	if ($_[0]->{version} > 105) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[4..5]);
	}
	if ($_[0]->{version} > 106) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[6]);
	}
}
sub state_export {
	cse_alife_space_restrictor::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0]);
	if ($_[0]->{version} < 113) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[1..2]);
	}
	if (($_[0]->{version} > 66) && ($_[0]->{version} < 118)) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[1]);
	}
	if ($_[0]->{version} > 102) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[3]);
	}
	if ($_[0]->{version} > 105) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[4..5]);
	}
	if ($_[0]->{version} > 106) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[6]);
	}
}
sub update_read {
	if (($_[0]->{version} > 101) && ($_[0]->{version} <= 118) && ($_[0]->{script_version} <= 5)) {
		$_[1]->unpack_properties($_[0], upd_properties_info);
	}
}
sub update_write {
	if (($_[0]->{version} > 101) && ($_[0]->{version} <= 118) && ($_[0]->{script_version} <= 5)) {
		$_[1]->pack_properties($_[0], upd_properties_info);
	}
}
sub update_import {
	if (($_[0]->{version} > 101) && ($_[0]->{version} <= 118) && ($_[0]->{script_version} <= 5)) {
		$_[1]->import_properties($_[2], $_[0], upd_properties_info);
	}
}
sub update_export {
	if (($_[0]->{version} > 101) && ($_[0]->{version} <= 118) && ($_[0]->{script_version} <= 5)) {
		$_[1]->export_properties(undef, $_[0], upd_properties_info);
	}
}
sub is_handled {return ($_[0]->{flags} & FL_HANDLED)}
######################################################################
package cse_alife_anomalous_zone;
use strict;
use constant FL_HANDLED => 0x20;
use constant properties_info => (
	{ name => 'offline_interactive_radius',	type => 'f32',	default => 0.0 },
	{ name => 'artefact_birth_probability',	type => 'f32',	default => 0.0 },
	{ name => 'artefact_spawns',	type => 'afspawns_u32',	default => [] },
	{ name => 'artefact_spawns',	type => 'afspawns',	default => [] },
	{ name => 'artefact_spawn_count',	type => 'u16',	default => 0 },
	{ name => 'artefact_position_offset',	type => 'h32',	default => 0 },
	{ name => 'start_time_shift',	type => 'u32',	default => 0 },
	{ name => 'cse_alife_anomalous_zone__unk2_f32',	type => 'f32',	default => 0.0 },
	{ name => 'min_start_power',	type => 'f32',	default => 0.0 },
	{ name => 'max_start_power',	type => 'f32',	default => 0.0 },
	{ name => 'power_artefact_factor',	type => 'f32',	default => 0.0 },
	{ name => 'owner_id',	type => 'h32',	default => 0 },
);
sub init {
	cse_alife_custom_zone::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_custom_zone::state_read(@_);
	if ($_[0]->{version} > 21) {
		$_[1]->unpack_properties($_[0], (properties_info)[0]);
		return if (ref($_[0]) eq 'cse_alife_custom_zone');	#some mod error handling
		if ($_[0]->{version} < 113) {
			$_[1]->unpack_properties($_[0], (properties_info)[1]);
			if ($_[0]->{version} < 26) {
				$_[1]->unpack_properties($_[0], (properties_info)[2]);
			} else {
				$_[1]->unpack_properties($_[0], (properties_info)[3]);
			}
		}
	}
	if ($_[0]->{version} > 25) {
		$_[1]->unpack_properties($_[0], (properties_info)[4..5]);
	}
	if (($_[0]->{version} > 27) && ($_[0]->{version} < 67)) {
		$_[1]->unpack_properties($_[0], (properties_info)[6]);
	}
	if (($_[0]->{version} > 38) && ($_[0]->{version} < 113)) {
		$_[1]->unpack_properties($_[0], (properties_info)[7]);
	}
	if ($_[0]->{version} > 78 && $_[0]->{version} < 113) {
		$_[1]->unpack_properties($_[0], (properties_info)[8..10]);
	}
	if ($_[0]->{version} == 102) {
		$_[1]->unpack_properties($_[0], (properties_info)[11]);
	}
}
sub state_write {
	cse_alife_custom_zone::state_write(@_);
	if ($_[0]->{version} > 21) {
		$_[1]->pack_properties($_[0], (properties_info)[0]);
		if ($_[0]->{version} < 113) {
			$_[1]->pack_properties($_[0], (properties_info)[1]);
			if ($_[0]->{version} < 26) {
				$_[1]->pack_properties($_[0], (properties_info)[2]);
			} else {
				$_[1]->pack_properties($_[0], (properties_info)[3]);
			}
		}
	}
	if ($_[0]->{version} > 25) {
		$_[1]->pack_properties($_[0], (properties_info)[4..5]);
	}
	if (($_[0]->{version} > 27) && ($_[0]->{version} < 67)) {
		$_[1]->pack_properties($_[0], (properties_info)[6]);
	}
	if (($_[0]->{version} > 38) && ($_[0]->{version} < 113)) {
		$_[1]->pack_properties($_[0], (properties_info)[7]);
	}
	if ($_[0]->{version} > 78 && $_[0]->{version} < 113) {
		$_[1]->pack_properties($_[0], (properties_info)[8..10]);
	}
	if ($_[0]->{version} == 102) {
		$_[1]->pack_properties($_[0], (properties_info)[11]);
	}
}
sub state_import {
	cse_alife_custom_zone::state_import(@_);
	if ($_[0]->{version} > 21) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[0]);
		if ($_[0]->{version} < 113) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[1]);
			if ($_[0]->{version} < 26) {
				$_[1]->import_properties($_[2], $_[0], (properties_info)[2]);
			} else {
				$_[1]->import_properties($_[2], $_[0], (properties_info)[3]);
			}
		}
	}
	if ($_[0]->{version} > 25) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[4..5]);
	}
	if (($_[0]->{version} > 27) && ($_[0]->{version} < 67)) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[6]);
	}
	if (($_[0]->{version} > 38) && ($_[0]->{version} < 113)) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[7]);
	}
	if ($_[0]->{version} > 78 && $_[0]->{version} < 113) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[8..10]);
	}
	if ($_[0]->{version} == 102) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[11]);
	}
}
sub state_export {
	cse_alife_custom_zone::state_export(@_);
	if ($_[0]->{version} > 21) {
		$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0]);
		if ($_[0]->{version} < 113) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[1]);
			if ($_[0]->{version} < 26) {
				$_[1]->export_properties(undef, $_[0], (properties_info)[2]);
			} else {
				$_[1]->export_properties(undef, $_[0], (properties_info)[3]);
			}
		}
	}
	if ($_[0]->{version} > 25) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[4..5]);
	}
	if (($_[0]->{version} > 27) && ($_[0]->{version} < 67)) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[6]);
	}
	if (($_[0]->{version} > 38) && ($_[0]->{version} < 113)) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[7]);
	}
	if ($_[0]->{version} > 78 && $_[0]->{version} < 113) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[8..10]);
	}
	if ($_[0]->{version} == 102) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[11]);
	}
}
sub update_read {
	cse_alife_custom_zone::update_read(@_);
}
sub update_write {
	cse_alife_custom_zone::update_write(@_);
}
sub update_import {
	cse_alife_custom_zone::update_import(@_);
}
sub update_export {
	cse_alife_custom_zone::update_export(@_);
}
sub is_handled {return ($_[0]->{flags} & FL_HANDLED)}
#######################################################################
package cse_alife_zone_visual;
use strict;
use constant FL_HANDLED => 0x20;
use constant properties_info => (
	{ name => 'idle_animation',	type => 'sz',	default => '' },
	{ name => 'attack_animation',	type => 'sz',	default => '' },
);
sub init {
	cse_alife_anomalous_zone::init(@_);
	cse_visual::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_anomalous_zone::state_read(@_);
	if (($_[0]->{version} > 104) || ($_[0]->{section_name} eq 'zone_burning_fuzz1')) {
		cse_visual::state_read(@_);
		$_[1]->unpack_properties($_[0], properties_info);
	}
}
sub state_write {
	cse_alife_anomalous_zone::state_write(@_);
	if (($_[0]->{version} > 104) || ($_[0]->{section_name} eq 'zone_burning_fuzz1')) {
		cse_visual::state_write(@_);
		$_[1]->pack_properties($_[0], properties_info);
	}
}
sub state_import {
	cse_alife_anomalous_zone::state_import(@_);
	if (($_[0]->{version} > 104) || ($_[0]->{section_name} eq 'zone_burning_fuzz1')) {
		cse_visual::state_import(@_);
		$_[1]->import_properties($_[2], $_[0], properties_info);
	}
}
sub state_export {
	cse_alife_anomalous_zone::state_export(@_);
	if (($_[0]->{version} > 104) || ($_[0]->{section_name} eq 'zone_burning_fuzz1')) {
		cse_visual::state_export(@_);
		$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
	}
}
sub update_read {
	cse_alife_custom_zone::update_read(@_);
}
sub update_write {
	cse_alife_custom_zone::update_write(@_);
}
sub update_import {
	cse_alife_custom_zone::update_import(@_);
}
sub update_export {
	cse_alife_custom_zone::update_export(@_);
}
sub is_handled {return ($_[0]->{flags} & FL_HANDLED)}
#######################################################################
package cse_alife_torrid_zone;
use strict;
sub init {
	cse_alife_custom_zone::init(@_);
	cse_motion::init(@_);
}
sub state_read {
	cse_alife_custom_zone::state_read(@_);
	cse_motion::state_read(@_);
}
sub state_write {
	cse_alife_custom_zone::state_write(@_);
	cse_motion::state_write(@_);
}
sub state_import {
	cse_alife_custom_zone::state_import(@_);
	cse_motion::state_import(@_);
}
sub state_export {
	cse_alife_custom_zone::state_export(@_);
	cse_motion::state_export(@_);
}
sub update_read {
	cse_alife_custom_zone::update_read(@_);
}
sub update_write {
	cse_alife_custom_zone::update_write(@_);
}
sub update_import {
	cse_alife_custom_zone::update_import(@_);
}
sub update_export {
	cse_alife_custom_zone::update_export(@_);
}
#######################################################################
package cse_alife_inventory_item;
use strict;
use stkutils::debug qw(fail warn);
use constant FLAG_NO_POSITION => 0x8000;
use constant FL_IS_2942 => 0x04;
use constant properties_info => (
	{ name => 'condition', type => 'f32', default => 0.0 },
	{ name => 'upgrades', type => 'l32szv', default => [] },
);
use constant upd_properties_info => (
	{ name => 'upd:num_items',			type => 'h8', default => 0 },
	{ name => 'upd:force',				type => 'f32v3', default => [0.0,0.0,0.0]  },			# junk in COP
	{ name => 'upd:torque',				type => 'f32v3', default => [0.0,0.0,0.0]  },			# junk in COP
	{ name => 'upd:position',			type => 'f32v3', default => [0.0,0.0,0.0]  },
	{ name => 'upd:quaternion',			type => 'f32v4', default => [0.0,0.0,0.0,0.0]  },
	{ name => 'upd:angular_velocity',	type => 'f32v3', default => [0.0,0.0,0.0]  },
	{ name => 'upd:linear_velocity',	type => 'f32v3', default => [0.0,0.0,0.0]  },
	{ name => 'upd:enabled',			type => 'u8', default => 0 },
	{ name => 'upd:quaternion',			type => 'q8v4', default => [0,0,0,0]  }, #SOC
	{ name => 'upd:angular_velocity',	type => 'q8v3', default => [0,0,0]  }, #SOC
	{ name => 'upd:linear_velocity',	type => 'q8v3', default => [0,0,0]  }, #SOC
	{ name => 'upd:condition',			type => 'f32', default => 0  },
	{ name => 'upd:timestamp',			type => 'u32', default => 0  },
	{ name => 'upd:num_items',			type => 'u16', default => 0  }, #old format
	{ name => 'upd:cse_alife_inventory_item__unk1_u8',			type => 'u8', default => 0  },
);
sub init {
	stkutils::file::entity::init_properties($_[0], properties_info);
	stkutils::file::entity::init_properties($_[0], upd_properties_info);
}
sub state_read {
	if ($_[0]->{version} > 52) {
		$_[1]->unpack_properties($_[0], (properties_info)[0]);
	}
	if ($_[0]->{version} > 123) {
		$_[1]->unpack_properties($_[0], (properties_info)[1]);
	}
}
sub state_write {
	if ($_[0]->{version} > 52) {
		$_[1]->pack_properties($_[0], (properties_info)[0]);
	}
	if ($_[0]->{version} > 123) {
		$_[1]->pack_properties($_[0], (properties_info)[1]);
	}
}
sub state_import {
	if ($_[0]->{version} > 52) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[0]);
	}
	if ($_[0]->{version} > 123) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[1]);
	}
}
sub state_export {
	if ($_[0]->{version} > 52) {
		$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0]);
	}
	if ($_[0]->{version} > 123) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[1]);
	}
}
sub update_read {
	if (($_[0]->{version} >= 122) && ($_[0]->{version} <= 128)) {
		$_[1]->unpack_properties($_[0], (upd_properties_info)[0]);
		if ($_[0]->{'upd:num_items'} != 0) {
			$_[1]->unpack_properties($_[0], (upd_properties_info)[1..4]);
			my $flags = $_[0]->{'upd:num_items'} >> 5;
			if (($flags & 0x2) == 0) {
				$_[1]->unpack_properties($_[0], (upd_properties_info)[5]);
			}
			if (($flags & 0x4) == 0) {
				$_[1]->unpack_properties($_[0], (upd_properties_info)[6]);
			}
			if ($_[1]->resid() != 0) {
				$_[1]->unpack_properties($_[0], (upd_properties_info)[7]);
			}
		}
	} elsif (($_[0]->{version} >= 118) && ($_[0]->{script_version} > 5)) {
		$_[1]->unpack_properties($_[0], (upd_properties_info)[0]);
		if ($_[0]->{'upd:num_items'} != 0) {
			$_[1]->unpack_properties($_[0], (upd_properties_info)[3]);
			$_[1]->unpack_properties($_[0], (upd_properties_info)[8]);
			my $flags = $_[0]->{'upd:num_items'} >> 5;
			if (($flags & 0x02 || $flags & 0x04) && $_[1]->resid() == 6) {
				$_[0]->{flags} |= FL_IS_2942;
			}
			if (first_patch($_[0]) || (($flags & 0x02) == 0)) {
				fail('unexpected size') unless $_[1]->resid() >= 3;
				$_[1]->unpack_properties($_[0], (upd_properties_info)[9]);
			}
			if (first_patch($_[0]) || (($flags & 0x04) == 0)) {
				fail('unexpected size') unless $_[1]->resid() >= 3;
				$_[1]->unpack_properties($_[0], (upd_properties_info)[10]);
			}
		}
	} else {
		if (($_[0]->{version} > 59) &&($_[0]->{version} <= 63)) {
			$_[1]->unpack_properties($_[0], (upd_properties_info)[14]);
		}
		$_[1]->unpack_properties($_[0], (upd_properties_info)[11..13]);
		my $flags = $_[0]->{'upd:num_items'};
		if ($flags != FLAG_NO_POSITION) {
			$_[1]->unpack_properties($_[0], (upd_properties_info)[3]);
		}
		if ($flags & ~FLAG_NO_POSITION) {
			$_[1]->unpack_properties($_[0], (upd_properties_info)[7]);
			$_[1]->unpack_properties($_[0], (upd_properties_info)[5..6]);
			$_[1]->unpack_properties($_[0], (upd_properties_info)[1..2]);
			$_[1]->unpack_properties($_[0], (upd_properties_info)[4]);
		}
	}
}
sub update_write {
	if (($_[0]->{version} >= 122) && ($_[0]->{version} <= 128)) {
		$_[1]->pack_properties($_[0], (upd_properties_info)[0]);
		if ($_[0]->{'upd:num_items'} != 0) {
			$_[1]->pack_properties($_[0], (upd_properties_info)[1..4]);
			my $flags = $_[0]->{'upd:num_items'} >> 5;
			if (($flags & 0x2) == 0) {
				$_[1]->pack_properties($_[0], (upd_properties_info)[5]);
			}
			if (($flags & 0x4) == 0) {
				$_[1]->pack_properties($_[0], (upd_properties_info)[6]);
			}
			if ($_[1]->resid() != 0) {
				$_[1]->pack_properties($_[0], (upd_properties_info)[7]);
			}
		}
	} elsif (($_[0]->{version} >= 118) && ($_[0]->{script_version} > 5)) {
	my $flags = ($_[0]->{'upd:num_items'});
	my $mask = $flags >> 5;
		$_[1]->pack_properties($_[0], (upd_properties_info)[0]);
		if ($flags != 0) {
			$_[1]->pack_properties($_[0], (upd_properties_info)[3]);
			$_[1]->pack_properties($_[0], (upd_properties_info)[8]);
			if (first_patch($_[0]) || (($mask & 0x02) == 0)) {
				$_[1]->pack_properties($_[0], (upd_properties_info)[9]);
			}
			if (first_patch($_[0]) || (($mask & 0x04) == 0)) {
				$_[1]->pack_properties($_[0], (upd_properties_info)[10]);
			}
		}
	} else {
		if (($_[0]->{version} > 59) &&($_[0]->{version} <= 63)) {
			$_[1]->pack_properties($_[0], (upd_properties_info)[14]);
		}
		$_[1]->pack_properties($_[0], (upd_properties_info)[11..13]);
		my $flags = $_[0]->{'upd:num_items'};
		if ($flags != 0x8000) {
			$_[1]->pack_properties($_[0], (upd_properties_info)[3]);
		}
		if ($flags & ~0x8000) {
			$_[1]->pack_properties($_[0], (upd_properties_info)[7]);
			$_[1]->pack_properties($_[0], (upd_properties_info)[5..6]);
			$_[1]->pack_properties($_[0], (upd_properties_info)[1..2]);
			$_[1]->pack_properties($_[0], (upd_properties_info)[4]);
		}
	}
}
sub update_import {
	if (($_[0]->{version} >= 122) && ($_[0]->{version} <= 128)) {
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[0]);
		if ($_[0]->{'upd:num_items'} != 0) {
			$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[1..4]);
			my $flags = $_[0]->{'upd:num_items'} >> 5;
			if (($flags & 0x2) == 0) {
				$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[5]);
			}
			if (($flags & 0x4) == 0) {
				$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[6]);
			}
			if (defined $_[1]->value($_[2], 'upd:enabled')) {
				$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[7]);
			}
		}
	} elsif (($_[0]->{version} >= 118) && ($_[0]->{script_version} > 5)) {
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[0]);
		if ($_[0]->{'upd:num_items'} != 0) {
			$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[3]);
			$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[8]);
			my $flags = $_[0]->{'upd:num_items'} >> 5;
			if (($flags & 0x02 || $flags & 0x04) && (defined $_[1]->value($_[2], 'upd:angular_velocity')) && (defined $_[1]->value($_[2], 'upd:linear_velocity'))) {
				$_[0]->{flags} |= FL_IS_2942;
			}
			if (first_patch($_[0]) || (($flags & 0x02) == 0)) {
				$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[9]);
			}
			if (first_patch($_[0]) || (($flags & 0x04) == 0)) {
				$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[10]);
			}
		}
	} else {
	if (($_[0]->{version} > 59) &&($_[0]->{version} <= 63)) {
			$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[14]);
		}
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[11..13]);
		my $flags = $_[0]->{'upd:num_items'};
		if ($flags != 0x8000) {
			$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[3]);
		}
		if ($flags & ~0x8000) {
			$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[7]);
			$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[5..6]);
			$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[1..2]);
			$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[4]);
		}
	}
}
sub update_export {
	if (($_[0]->{version} >= 122) && ($_[0]->{version} <= 128)) {
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[0]);
		if ($_[0]->{'upd:num_items'} != 0) {
			$_[1]->export_properties(undef, $_[0], (upd_properties_info)[1..4]);
			my $flags = $_[0]->{'upd:num_items'} >> 5;
			if (($flags & 0x2) == 0) {
				$_[1]->export_properties(undef, $_[0], (upd_properties_info)[5]);
			}
			if (($flags & 0x4) == 0) {
				$_[1]->export_properties(undef, $_[0], (upd_properties_info)[6]);
			}
			if ($_[0]->{'upd:enabled'} == 0 || $_[0]->{'upd:enabled'} == 1) {
				$_[1]->export_properties(undef, $_[0], (upd_properties_info)[7]);
			}
		}
	} elsif (($_[0]->{version} >= 118) && ($_[0]->{script_version} > 5)) {
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[0]);
		if ($_[0]->{'upd:num_items'} != 0) {
			$_[1]->export_properties(undef, $_[0], (upd_properties_info)[3]);
			$_[1]->export_properties(undef, $_[0], (upd_properties_info)[8]);
			my $flags = $_[0]->{'upd:num_items'} >> 5;
			if (first_patch($_[0]) || (($flags & 0x02) == 0)) {
				$_[1]->export_properties(undef, $_[0], (upd_properties_info)[9]);
			}
			if (first_patch($_[0]) || (($flags & 0x04) == 0)) {
				$_[1]->export_properties(undef, $_[0], (upd_properties_info)[10]);
			}
		}
	} else {
		if (($_[0]->{version} > 59) &&($_[0]->{version} <= 63)) {
			$_[1]->export_properties(undef, $_[0], (upd_properties_info)[14]);
		}
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[11..13]);
		my $flags = $_[0]->{'upd:num_items'};
		if ($flags != 0x8000) {
			$_[1]->export_properties(undef, $_[0], (upd_properties_info)[3]);
		}
		if ($flags & ~0x8000) {
			$_[1]->export_properties(undef, $_[0], (upd_properties_info)[7]);
			$_[1]->export_properties(undef, $_[0], (upd_properties_info)[5..6]);
			$_[1]->export_properties(undef, $_[0], (upd_properties_info)[1..2]);
			$_[1]->export_properties(undef, $_[0], (upd_properties_info)[4]);
		}
	}
}
sub first_patch {
	return $_[0]->{flags} & FL_IS_2942;
}
#######################################################################
package cse_alife_item;
use strict;
sub init {
	cse_alife_dynamic_object_visual::init(@_);
	cse_alife_inventory_item::init(@_);
}
sub state_read {
	cse_alife_dynamic_object_visual::state_read(@_);
	if ($_[0]->{version} > 39) {
		cse_alife_inventory_item::state_read(@_);
	}
}
sub state_write {
	cse_alife_dynamic_object_visual::state_write(@_);
	if ($_[0]->{version} > 39) {
		cse_alife_inventory_item::state_write(@_);
	}
}
sub state_import {
	cse_alife_dynamic_object_visual::state_import(@_);
	if ($_[0]->{version} > 39) {
		cse_alife_inventory_item::state_import(@_);
	}
}
sub state_export {
	cse_alife_dynamic_object_visual::state_export(@_);
	if ($_[0]->{version} > 39) {
		cse_alife_inventory_item::state_export(@_);
	}
}
sub update_read {
	if ($_[0]->{version} > 39) {
		cse_alife_inventory_item::update_read(@_);
	}
}
sub update_write {
	if ($_[0]->{version} > 39) {
		cse_alife_inventory_item::update_write(@_);
	}
}
sub update_import {
	if ($_[0]->{version} > 39) {
		cse_alife_inventory_item::update_import(@_);
	}
}
sub update_export {
	if ($_[0]->{version} > 39) {
		cse_alife_inventory_item::update_export(@_);
	}
}
#######################################################################
package cse_alife_item_binocular;
use strict;
use constant properties_info => (
	{ name => 'cse_alife_item__unk1_s16', type => 's16', default => 0 },
	{ name => 'cse_alife_item__unk2_s16', type => 's16', default => 0 },
	{ name => 'cse_alife_item__unk3_s8', type => 's8', default => 0 },
);
sub init {
	cse_alife_item::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_item::state_read(@_);
	if ($_[0]->{version} < 37) {
		$_[1]->unpack_properties($_[0], properties_info);
	}
}
sub state_write {
	cse_alife_item::state_write(@_);
	if ($_[0]->{version} < 37) {
		$_[1]->pack_properties($_[0], properties_info);
	}
}
sub state_import {
	cse_alife_item::state_import(@_);
	if ($_[0]->{version} < 37) {
		$_[1]->import_properties($_[2], $_[0], properties_info);
	}
}
sub state_export {
	cse_alife_item::state_write(@_);
	if ($_[0]->{version} < 37) {
		$_[1]->export_properties(undef, $_[0], properties_info);
	}
}
sub update_read {
	cse_alife_item::update_read(@_);
}
sub update_write {
	cse_alife_item::update_write(@_);
}
sub update_import {
	cse_alife_item::update_import(@_);
}
sub update_export {
	cse_alife_item::update_export(@_);
}
#######################################################################
package cse_alife_item_torch;
use strict;
use constant flTorchActive		=> 0x01;
use constant flTorchNightVisionActive	=> 0x02;
use constant flTorchUnknown		=> 0x04;
use constant properties_info => (
	{ name => 'main_color',		type => 'h32',	default => 0x00ffffff },
	{ name => 'main_color_animator',type => 'sz',	default => '' },
	{ name => 'animation',	type => 'sz',	default => '$editor' },
	{ name => 'ambient_radius',	type => 'f32',	default => 0.0 },
	{ name => 'main_cone_angle',	type => 'q8',	default => 0.0 },
	{ name => 'main_virtual_size',	type => 'f32',	default => 0.0 },
	{ name => 'glow_texture',	type => 'sz',	default => '' },
	{ name => 'glow_radius',	type => 'f32',	default => 0.0 },
	{ name => 'cse_alife_object_hanging_lamp__unk3_u8',	type => 'u16',	default => 0 },
);
use constant upd_properties_info => (
	{ name => 'upd:torch_flags', type => 'u8', default => -1 },
);
sub init {
	cse_alife_item::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
	stkutils::file::entity::init_properties($_[0], upd_properties_info);
}
sub state_read {
	if ($_[0]->{version} > 20) {
		cse_alife_item::state_read(@_);
	}
	if ($_[0]->{version} < 48) {
		$_[1]->unpack_properties($_[0], (properties_info)[0..5]);
		if ($_[0]->{version} > 40) {
			$_[1]->unpack_properties($_[0], (properties_info)[6..7]);
		}
		if ($_[0]->{version} > 45) {
			$_[1]->unpack_properties($_[0], (properties_info)[8]);
		}
	}
}
sub state_write {
	if ($_[0]->{version} > 20) {
		cse_alife_item::state_write(@_);
	}
	if ($_[0]->{version} < 48) {
		$_[1]->pack_properties($_[0], (properties_info)[0..5]);
		if ($_[0]->{version} > 40) {
			$_[1]->pack_properties($_[0], (properties_info)[6..7]);
		}
		if ($_[0]->{version} > 45) {
			$_[1]->pack_properties($_[0], (properties_info)[8]);
		}
	}
}
sub state_import {
	if ($_[0]->{version} > 20) {
		cse_alife_item::state_import(@_);
	}
	if ($_[0]->{version} < 48) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[0..5]);
		if ($_[0]->{version} > 40) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[6..7]);
		}
		if ($_[0]->{version} > 45) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[8]);
		}
	}
}
sub state_export {
	if ($_[0]->{version} > 20) {
		cse_alife_item::state_export(@_);
	}
	if ($_[0]->{version} < 48) {
		$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0..5]);
		if ($_[0]->{version} > 40) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[6..7]);
		}
		if ($_[0]->{version} > 45) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[8]);
		}
	}
}
sub update_read {
	cse_alife_item::update_read(@_);
	$_[1]->unpack_properties($_[0], upd_properties_info);
}
sub update_write {
	cse_alife_item::update_write(@_);
	$_[1]->pack_properties($_[0], upd_properties_info);
}
sub update_import {
	cse_alife_item::update_import(@_);
	$_[1]->import_properties($_[2], $_[0], upd_properties_info);
}
sub update_export {
	cse_alife_item::update_export(@_);
	$_[1]->export_properties(undef, $_[0], upd_properties_info);
}
#######################################################################
package cse_alife_item_detector;
use strict;
sub init {
	cse_alife_item::init(@_);
}
sub state_read {
	if ($_[0]->{version} > 20) {
		cse_alife_item::state_read(@_);
	}
}
sub state_write {
	if ($_[0]->{version} > 20) {
		cse_alife_item::state_write(@_);
	}
}
sub state_import {
	if ($_[0]->{version} > 20) {
	cse_alife_item::state_import(@_);
	}
}
sub state_export {
	if ($_[0]->{version} > 20) {
	cse_alife_item::state_export(@_);
	}
}
sub update_read {
	if ($_[0]->{version} > 20) {
		cse_alife_item::update_read(@_);
	}
}
sub update_write {
	if ($_[0]->{version} > 20) {
		cse_alife_item::update_write(@_);
	}
}
sub update_import {
	if ($_[0]->{version} > 20) {
		cse_alife_item::update_import(@_);
	}
}
sub update_export {
	if ($_[0]->{version} > 20) {
		cse_alife_item::update_export(@_);
	}
}
#######################################################################
package cse_alife_item_artefact;
use strict;
sub init {
	cse_alife_item::init(@_);
}
sub state_read {
	cse_alife_item::state_read(@_);
}
sub state_write {
	cse_alife_item::state_write(@_);
}
sub state_import {
	cse_alife_item::state_import(@_);
}
sub state_export {
	cse_alife_item::state_export(@_);
}
sub update_read {
	cse_alife_item::update_read(@_);
}
sub update_write {
	cse_alife_item::update_write(@_);
}
sub update_import {
	cse_alife_item::update_import(@_);
}
sub update_export {
	cse_alife_item::update_export(@_);
}
#######################################################################
package cse_alife_item_grenade;
use strict;
sub init {
	cse_alife_item::init(@_);
}
sub state_read {
	cse_alife_item::state_read(@_);
}
sub state_write {
	cse_alife_item::state_write(@_);
}
sub state_import {
	cse_alife_item::state_import(@_);
}
sub state_export {
	cse_alife_item::state_export(@_);
}
sub update_read {
	cse_alife_item::update_read(@_);
}
sub update_write {
	cse_alife_item::update_write(@_);
}
sub update_import {
	cse_alife_item::update_import(@_);
}
sub update_export {
	cse_alife_item::update_export(@_);
}
#######################################################################
package cse_alife_item_explosive;
use strict;
sub init {
	cse_alife_item::init(@_);
}
sub state_read {
	cse_alife_item::state_read(@_);
}
sub state_write {
	cse_alife_item::state_write(@_);
}
sub state_import {
	cse_alife_item::state_import(@_);
}
sub state_export {
	cse_alife_item::state_export(@_);
}
sub update_read {
	cse_alife_item::update_read(@_);
}
sub update_write {
	cse_alife_item::update_write(@_);
}
sub update_import {
	cse_alife_item::update_import(@_);
}
sub update_export {
	cse_alife_item::update_export(@_);
}
#######################################################################
package cse_alife_item_bolt;
use strict;
sub init {
	cse_alife_item::init(@_);
}
sub state_read {
	cse_alife_item::state_read(@_);
}
sub state_write {
	cse_alife_item::state_write(@_);
}
sub state_import {
	cse_alife_item::state_import(@_);
}
sub state_export {
	cse_alife_item::state_export(@_);
}
sub update_read {
	cse_alife_item::update_read(@_);
}
sub update_write {
	cse_alife_item::update_write(@_);
}
sub update_import {
	cse_alife_item::update_import(@_);
}
sub update_export {
	cse_alife_item::update_export(@_);
}
#######################################################################
package cse_alife_item_custom_outfit;
use strict;
use constant upd_properties_info => (
	{ name => 'upd:condition', type => 'q8', default => 0},
);
sub init {
	cse_alife_item::init(@_);
	stkutils::file::entity::init_properties($_[0], upd_properties_info);
}
sub state_read {
	cse_alife_item::state_read(@_);
}
sub state_write {
	cse_alife_item::state_write(@_);
}
sub state_import {
	cse_alife_item::state_import(@_);
}
sub state_export {
	cse_alife_item::state_export(@_);
}
sub update_read {
	cse_alife_item::update_read(@_);
	if (($_[0]->{version} >= 118) && ($_[0]->{script_version} > 5)) {
		$_[1]->unpack_properties($_[0], upd_properties_info);
	}
}
sub update_write {
	cse_alife_item::update_write(@_);
	if (($_[0]->{version} >= 118) && ($_[0]->{script_version} > 5)) {
		$_[1]->pack_properties($_[0], upd_properties_info);
	}
}
sub update_import {
	cse_alife_item::update_import(@_);
	if (($_[0]->{version} >= 118) && ($_[0]->{script_version} > 5)) {
		$_[1]->import_properties($_[2], $_[0], upd_properties_info);
	}
}
sub update_export {
	cse_alife_item::update_export(@_);
	if (($_[0]->{version} >= 118) && ($_[0]->{script_version} > 5)) {
		$_[1]->export_properties(undef, $_[0], upd_properties_info);
	}
}
#######################################################################
package cse_alife_item_helmet;
use strict;
use constant upd_properties_info => (
	{ name => 'upd:condition', type => 'q8', default => 0},
);
sub init {
	cse_alife_item::init(@_);
	stkutils::file::entity::init_properties($_[0], upd_properties_info);
}
sub state_read {
	cse_alife_item::state_read(@_);
}
sub state_write {
	cse_alife_item::state_write(@_);
}
sub state_import {
	cse_alife_item::state_import(@_);
}
sub state_export {
	cse_alife_item::state_export(@_);
}
sub update_read {	
	cse_alife_item::update_read(@_);
	if (($_[0]->{version} >= 118) && ($_[0]->{script_version} > 5)) {
		$_[1]->unpack_properties($_[0], upd_properties_info);
	}
}
sub update_write {
	cse_alife_item::update_write(@_);
	if (($_[0]->{version} >= 118) && ($_[0]->{script_version} > 5)) {
		$_[1]->pack_properties($_[0], upd_properties_info);
	}
}
sub update_import {
	cse_alife_item::update_import(@_);
	if (($_[0]->{version} >= 118) && ($_[0]->{script_version} > 5)) {
		$_[1]->import_properties($_[2], $_[0], upd_properties_info);
	}
}
sub update_export {
	cse_alife_item::update_export(@_);
	if (($_[0]->{version} >= 118) && ($_[0]->{script_version} > 5)) {
		$_[1]->export_properties(undef, $_[0], upd_properties_info);
	}
}
#######################################################################
package cse_alife_item_pda;
use strict;
use constant properties_info => (
	{ name => 'original_owner',	type => 'u16',	default => 0 },
	{ name => 'specific_character',	type => 'sz',	default => '' },
	{ name => 'info_portion',	type => 'sz',	default => '' },
	{ name => 'cse_alife_item_pda__unk1_s32',	type => 's32',	default => -1 },
	{ name => 'cse_alife_item_pda__unk2_s32',	type => 's32',	default => -1 },
);
sub init {
	cse_alife_item::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_item::state_read(@_);
	if ($_[0]->{version} > 58) {
		$_[1]->unpack_properties($_[0], (properties_info)[0]);
	}
	if ($_[0]->{version} > 89) {
		if ($_[0]->{version} < 98) {
			$_[1]->unpack_properties($_[0], (properties_info)[3..4]);
		} else {
			$_[1]->unpack_properties($_[0], (properties_info)[1..2]);
		}
	}
}
sub state_write {
	cse_alife_item::state_write(@_);
	if ($_[0]->{version} > 58) {
		$_[1]->pack_properties($_[0], (properties_info)[0]);
	}
	if ($_[0]->{version} > 89) {
		if ($_[0]->{version} < 98) {
			$_[1]->pack_properties($_[0], (properties_info)[3..4]);
		} else {
			$_[1]->pack_properties($_[0], (properties_info)[1..2]);
		}
	}
}
sub state_import {
	cse_alife_item::state_import(@_);
	if ($_[0]->{version} > 58) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[0]);
	}
	if ($_[0]->{version} > 89) {
		if ($_[0]->{version} < 98) {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[3..4]);
		} else {
			$_[1]->import_properties($_[2], $_[0], (properties_info)[1..2]);
		}
	}
}
sub state_export {
	cse_alife_item::state_export(@_);
	if ($_[0]->{version} > 58) {
		$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0]);
	}
	if ($_[0]->{version} > 89) {
		if ($_[0]->{version} < 98) {
			$_[1]->export_properties(undef, $_[0], (properties_info)[3..4]);
		} else {
			$_[1]->export_properties(undef, $_[0], (properties_info)[1..2]);
		}
	}
}
sub update_read {
	cse_alife_item::update_read(@_);
}
sub update_write {
	cse_alife_item::update_write(@_);
}
sub update_import {
	cse_alife_item::update_import(@_);
}
sub update_export {
	cse_alife_item::update_export(@_);
}
#######################################################################
package cse_alife_item_document;
use strict;
use constant properties_info => (
	{ name => 'info_portion', type => 'sz', default => '' },
	{ name => 'info_id', type => 'u16', default => 0 },
);
sub init {
	cse_alife_item::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_item::state_read(@_);
	if ($_[0]->{version} < 98) {
		$_[1]->unpack_properties($_[0], (properties_info)[1]);
	} else {
		$_[1]->unpack_properties($_[0], (properties_info)[0]);
	}
}
sub state_write {
	cse_alife_item::state_write(@_);
	if ($_[0]->{version} < 98) {
		$_[1]->pack_properties($_[0], (properties_info)[1]);
	} else {
		$_[1]->pack_properties($_[0], (properties_info)[0]);
	}
}
sub state_import {
	cse_alife_item::state_import(@_);
	if ($_[0]->{version} < 98) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[1]);
	} else {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[0]);
	}
}
sub state_export {
	cse_alife_item::state_export(@_);
	if ($_[0]->{version} < 98) {
		$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[1]);
	} else {
		$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0]);
	}
}
sub update_read {
	cse_alife_item::update_read(@_);
}
sub update_write {
	cse_alife_item::update_write(@_);
}
sub update_import {
	cse_alife_item::update_import(@_);
}
sub update_export {
	cse_alife_item::update_export(@_);
}
#######################################################################
package cse_alife_item_ammo;
use strict;
use constant properties_info => (
	{ name => 'ammo_left', type => 'u16', default => 0 },
);
use constant upd_properties_info => (
	{ name => 'upd:ammo_left', type => 'u16', default => 0},
);
sub init {
	cse_alife_item::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
	stkutils::file::entity::init_properties($_[0], upd_properties_info);
}
sub state_read {
	cse_alife_item::state_read(@_);
	$_[1]->unpack_properties($_[0], properties_info);
}
sub state_write {
	cse_alife_item::state_write(@_);
	$_[1]->pack_properties($_[0], properties_info);
}
sub state_import {
	cse_alife_item::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub state_export {
	cse_alife_item::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
}
sub update_read {
	cse_alife_item::update_read(@_);
	$_[1]->unpack_properties($_[0], upd_properties_info);
}
sub update_write {
	cse_alife_item::update_write(@_);
	$_[1]->pack_properties($_[0], upd_properties_info);
}
sub update_import {
	cse_alife_item::update_import(@_);
	$_[1]->import_properties($_[2], $_[0], upd_properties_info);
}
sub update_export {
	cse_alife_item::update_export(@_);
	$_[1]->export_properties(undef, $_[0], upd_properties_info);
}
#######################################################################
package cse_alife_item_weapon;
use strict;
use constant flAddonScope	=> 0x01;
use constant flAddonLauncher	=> 0x02;
use constant flAddonSilencer	=> 0x04;
use constant FL_HANDLED => 0x20;
use constant properties_info => (
	{ name => 'ammo_current',	type => 'u16',	default => 0 },
	{ name => 'ammo_elapsed',	type => 'u16',	default => 0 },
	{ name => 'weapon_state',	type => 'u8',	default => 0 },
	{ name => 'addon_flags',	type => 'u8',	default => 0 },
	{ name => 'ammo_type',		type => 'u8',	default => 0 },
	{ name => 'cse_alife_item_weapon__unk1_u8',		type => 'u8',	default => 0 },
);
use constant upd_properties_info => (
	{ name => 'upd:condition',	type => 'q8', default => 0 },
	{ name => 'upd:weapon_flags',	type => 'u8', default => 0  },
	{ name => 'upd:ammo_elapsed',	type => 'u16', default => 0  },
	{ name => 'upd:addon_flags',	type => 'u8', default => 0  },	
	{ name => 'upd:ammo_type',	type => 'u8', default => 0  },
	{ name => 'upd:weapon_state',	type => 'u8', default => 0  },
	{ name => 'upd:weapon_zoom',	type => 'u8', default => 0  },
	{ name => 'upd:ammo_current',	type => 'u16', default => 0  },
	{ name => 'upd:position',	type => 'f32v3', default => [0,0,0]  },
	{ name => 'upd:timestamp',	type => 'u32', default => 0  },
);
sub init {
	cse_alife_item::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
	stkutils::file::entity::init_properties($_[0], upd_properties_info);
}
sub state_read {
	cse_alife_item::state_read(@_);
	$_[1]->unpack_properties($_[0], (properties_info)[0..2]);
	if ($_[0]->{version} >= 40) {
		$_[1]->unpack_properties($_[0], (properties_info)[3]);
	}
	if ($_[0]->{version} > 46) {
		$_[1]->unpack_properties($_[0], (properties_info)[4]);
	}
	if ($_[0]->{version} > 122) {
		$_[1]->unpack_properties($_[0], (properties_info)[5]);
	}
	if (($_[1]->resid() == 1)) {						## LA
		$_[1]->unpack_properties($_[0], (properties_info)[5]);
		$_[0]->{flags} |= stkutils::file::entity::FL_LA;
	}
}
sub state_write {
	cse_alife_item::state_write(@_);
	$_[1]->pack_properties($_[0], (properties_info)[0..2]);
	if ($_[0]->{version} >= 40) {
		$_[1]->pack_properties($_[0], (properties_info)[3]);
	}
	if ($_[0]->{version} > 46) {
		$_[1]->pack_properties($_[0], (properties_info)[4]);
	}
	if ($_[0]->{version} > 122 || ($_[0]->{flags} & stkutils::file::entity::FL_LA == stkutils::file::entity::FL_LA)) {
		$_[1]->pack_properties($_[0], (properties_info)[5]);
	}
}
sub state_import {
	cse_alife_item::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], (properties_info)[0..2]);
	if ($_[0]->{version} >= 40) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[3]);
	}
	if ($_[0]->{version} > 46) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[4]);
	}
	if ($_[0]->{version} > 122 || ($_[0]->{flags} & stkutils::file::entity::FL_LA == stkutils::file::entity::FL_LA)) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[5]);
	}
}
sub state_export {
	cse_alife_item::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], (properties_info)[0..2]);
	if ($_[0]->{version} >= 40) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[3]);
	}
	if ($_[0]->{version} > 46) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[4]);
	}
	if ($_[0]->{version} > 122 || ($_[0]->{flags} & stkutils::file::entity::FL_LA == stkutils::file::entity::FL_LA)) {
		$_[1]->export_properties(undef, $_[0], (properties_info)[5]);
	}
}
sub update_read {
	cse_alife_item::update_read(@_);
	if (($_[0]->{version} >= 118) && ($_[0]->{script_version} > 5)) {
		$_[1]->unpack_properties($_[0], (upd_properties_info)[0]);
	}
	if ($_[0]->{version} > 39) {
		$_[1]->unpack_properties($_[0], (upd_properties_info)[1..6]);
	} else {
		$_[1]->unpack_properties($_[0], (upd_properties_info)[9]);
		$_[1]->unpack_properties($_[0], (upd_properties_info)[1]);
		$_[1]->unpack_properties($_[0], (upd_properties_info)[7]);
		$_[1]->unpack_properties($_[0], (upd_properties_info)[2]);
		$_[1]->unpack_properties($_[0], (upd_properties_info)[8]);
		$_[1]->unpack_properties($_[0], (upd_properties_info)[3..5]);
	}
}
sub update_write {
	cse_alife_item::update_write(@_);
	if (($_[0]->{version} >= 118) && ($_[0]->{script_version} > 5)) {
		$_[1]->pack_properties($_[0], (upd_properties_info)[0]);
	}
	if ($_[0]->{version} > 39) {
		$_[1]->pack_properties($_[0], (upd_properties_info)[1..6]);
	} else {
		$_[1]->pack_properties($_[0], (upd_properties_info)[9]);
		$_[1]->pack_properties($_[0], (upd_properties_info)[1]);
		$_[1]->pack_properties($_[0], (upd_properties_info)[7]);
		$_[1]->pack_properties($_[0], (upd_properties_info)[2]);
		$_[1]->pack_properties($_[0], (upd_properties_info)[8]);
		$_[1]->pack_properties($_[0], (upd_properties_info)[3..5]);
	}
}
sub update_import {
	cse_alife_item::update_import(@_);
	if (($_[0]->{version} >= 118) && ($_[0]->{script_version} > 5)) {
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[0]);
	}
	if ($_[0]->{version} > 39) {
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[1..6]);
	} else {
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[9]);
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[1]);
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[7]);
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[2]);
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[8]);
		$_[1]->import_properties($_[2], $_[0], (upd_properties_info)[3..5]);
	}
}
sub update_export {
	cse_alife_item::update_export(@_);
	if (($_[0]->{version} >= 118) && ($_[0]->{script_version} > 5)) {
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[0]);
	}
	if ($_[0]->{version} > 39) {
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[1..6]);
	} else {
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[9]);
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[1]);
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[7]);
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[2]);
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[8]);
		$_[1]->export_properties(undef, $_[0], (upd_properties_info)[3..5]);
	}
}
sub is_handled {return ($_[0]->{flags} & FL_HANDLED)}
#######################################################################
package cse_alife_item_weapon_magazined;
use strict;
use constant FL_HANDLED => 0x20;
use constant upd_properties_info => (
	{ name => 'upd:current_fire_mode', type => 'u8', default => 0 },
);
sub init {
	cse_alife_item_weapon::init(@_);
	stkutils::file::entity::init_properties($_[0], upd_properties_info);
}
sub state_read {
	cse_alife_item_weapon::state_read(@_);
}
sub state_write {
	cse_alife_item_weapon::state_write(@_);
}
sub state_import {
	cse_alife_item_weapon::state_import(@_);
}
sub state_export {
	cse_alife_item_weapon::state_export(@_);
}
sub update_read {
	cse_alife_item_weapon::update_read(@_);
	return if UNIVERSAL::can($_[0], 'is_handled') && $_[0]->is_handled();
	$_[1]->unpack_properties($_[0], upd_properties_info);
}
sub update_write {
	cse_alife_item_weapon::update_write(@_);
	$_[1]->pack_properties($_[0], upd_properties_info);
}
sub update_import {
	cse_alife_item_weapon::update_import(@_);
	$_[1]->import_properties($_[2], $_[0], upd_properties_info);
}
sub update_export {
	cse_alife_item_weapon::update_export(@_);
	$_[1]->export_properties(undef, $_[0], upd_properties_info);
}
sub is_handled {return ($_[0]->{flags} & FL_HANDLED)}
#######################################################################
package cse_alife_item_weapon_magazined_w_gl;
use strict;
use constant upd_properties_info => (
	{ name => 'upd:grenade_mode', type => 'u8', default => 0 },
);
sub init {
	cse_alife_item_weapon_magazined::init(@_);
	stkutils::file::entity::init_properties($_[0], upd_properties_info);
}
sub state_read {
	cse_alife_item_weapon::state_read(@_);
}
sub state_write {
	cse_alife_item_weapon::state_write(@_);
}
sub state_import {
	cse_alife_item_weapon_magazined::state_import(@_);
}
sub state_export {
	cse_alife_item_weapon_magazined::state_export(@_);
}
sub update_read {
	if ($_[0]->{version} >= 118) {
		$_[1]->unpack_properties($_[0], upd_properties_info);
	}
	cse_alife_item_weapon_magazined::update_read(@_);
}
sub update_write {	
	if ($_[0]->{version} >= 118) {
		$_[1]->pack_properties($_[0], upd_properties_info);
	}
	cse_alife_item_weapon_magazined::update_write(@_);
}
sub update_import {
	cse_alife_item_weapon_magazined::update_import(@_);
	if ($_[0]->{version} >= 118) {
		$_[1]->import_properties($_[2], $_[0], upd_properties_info);
	}
}
sub update_export {
	cse_alife_item_weapon_magazined::update_export(@_);
	if ($_[0]->{version} >= 118) {
		$_[1]->export_properties(undef, $_[0], upd_properties_info);
	}
}
#######################################################################
package cse_alife_item_weapon_shotgun;
use strict;
use constant upd_properties_info => (
	{ name => 'upd:ammo_ids', type => 'l8u8v', default => [] },
);
sub init {
	cse_alife_item_weapon_magazined::init(@_);
	stkutils::file::entity::init_properties($_[0], upd_properties_info);
}
sub state_read {
	cse_alife_item_weapon::state_read(@_);
}
sub state_write {
	cse_alife_item_weapon::state_write(@_);
}
sub state_import {
	cse_alife_item_weapon_magazined::state_import(@_);
}
sub state_export {
	cse_alife_item_weapon_magazined::state_export(@_);
}
sub update_read {
	cse_alife_item_weapon_magazined::update_read(@_);
	return if UNIVERSAL::can($_[0], 'is_handled') && $_[0]->is_handled();
	$_[1]->unpack_properties($_[0], upd_properties_info);
}
sub update_write {
	cse_alife_item_weapon_magazined::update_write(@_);
	$_[1]->pack_properties($_[0], upd_properties_info);
}
sub update_import {
	cse_alife_item_weapon_magazined::update_import(@_);
	$_[1]->import_properties($_[2], $_[0], upd_properties_info);
}
sub update_export {
	cse_alife_item_weapon_magazined::update_export(@_);
	$_[1]->export_properties(undef, $_[0], upd_properties_info);
}
#######################################################################
package se_actor;
use strict;
use constant FL_LEVEL_SPAWN => 0x01;
use constant FL_SAVE => 0x40;
use constant CRandomTask_info => (
	{ name => 'inited_tasks',				type => 'inited_tasks',	default => [] },
	{ name => 'rewards',					type => 'rewards',	default => [] },
	{ name => 'inited_find_upgrade_tasks',	type => 'inited_find_upgrade_tasks',	default => [] },
);
use constant object_collection_info => (
	{ name => 'm_count',					type => 'u16',	default => 0 },
	{ name => 'm_last_id',					type => 'u16',	default => 0 },
	{ name => 'm_free',						type => 'l16u16v',	default => [] },
	{ name => 'm_given',					type => 'l16u16v',	default => [] },
);
use constant object_collection_task_info => (
	{ name => 'task:m_count',					type => 'u16',	default => 0 },
	{ name => 'task:m_last_id',					type => 'u16',	default => 0 },
	{ name => 'task:m_free',						type => 'l16u16v',	default => [] },
	{ name => 'task:m_given',					type => 'l16u16v',	default => [] },
);
use constant CMinigames_info => (
	{ name => 'minigames',					type => 'minigames',	default => [] },
);
use constant properties_info => (
	{ name => 'start_position_filled',	type => 'u8',	default => 0 },
	{ name => 'dumb_1',	type => 'dumb_1' , default => [0,0,0,0,0,0,0,0,0,0,8,0,0,0,0,15,0,0,0,0,0,0,0,0,0,8,0,2,0,116,101,115,116,95,99,114,111,119,107,105,108,108,101,114,0,67,77,71,67,114,111,119,75,105,108,108,101,114,0,118,97,108,105,97,98,108,101,0,0,60,0,0,4,0,0,0,0,10,0,100,0,0,0,0,0,0,10,0,0,0,22,0,116,101,115,116,95,115,104,111,111,116,105,110,103,0,67,77,71,83,104,111,111,116,105,110,103,0,118,97,108,105,97,98,108,101,0,0,0,110,105,108,0,110,105,108,0,110,105,108,0,110,105,108,0,110,105,108,0,1,0,0,0,0,0,0,0,0,0,0,0,110,105,108,0,38,0,140,0,169,0] },
	{ name => 'dumb_2',	type => 'dumb_2' , default => [0,0,0,0,0,0,0,0,0,0,8,0,0,0,0,15,0,0,0,0,0,0,0,0,0,8,0,2,0,116,101,115,116,95,99,114,111,119,107,105,108,108,101,114,0,67,77,71,67,114,111,119,75,105,108,108,101,114,0,118,97,108,105,97,98,108,101,0,0,60,0,0,4,0,0,0,0,10,0,100,0,0,0,0,0,0,10,0,0,0,22,0,116,101,115,116,95,115,104,111,111,116,105,110,103,0,67,77,71,83,104,111,111,116,105,110,103,0,118,97,108,105,97,98,108,101,0,0,0,110,105,108,0,110,105,108,0,110,105,108,0,110,105,108,0,110,105,108,0,1,0,0,0,0,0,0,0,0,0] },
	{ name => 'dumb_3',	type => 'dumb_3' , default => [0,0,0,0,0,0,0,0,0,0,8,0,0,0,0,15,0,0,0,0,0,0,0,0,0,8,0,2,0,116,101,115,116,95,99,114,111,119,107,105,108,108,101,114,0,67,77,71,67,114,111,119,75,105,108,108,101,114,0,118,97,108,105,97,98,108,101,0,0,60,0,0,4,0,0,0,0,10,0,100,0,0,0,0,0,0,10,0,0,0,22,0,116,101,115,116,95,115,104,111,111,116,105,110,103,0,67,77,71,83,104,111,111,116,105,110,103,0,118,97,108,105,97,98,108,101,0,0,0,110,105,108,0,110,105,108,0,110,105,108,0,110,105,108,0,110,105,108,0,1,0,0,0,0,0] },
);
sub init {
	cse_alife_creature_actor::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_creature_actor::state_read(@_);
	return if $_[0]->{version} < 122;
	$_[1]->set_save_marker($_[0], 'load', 0, 'se_actor') if $_[0]->{version} > 123;
	if ($_[0]->{version} >= 128) {
		$_[1]->unpack_properties($_[0], (properties_info)[0]);
	} elsif ($_[0]->{version} >= 122) {
		if ($_[0]->is_save()) {
			CRandomTask_read(@_);
			object_collection_read(@_);
			CMinigames_read(@_);
		} else {
			if ($_[0]->{version} >= 124) {
				$_[1]->unpack_properties($_[0], (properties_info)[1]);
			} elsif ($_[0]->{version} >= 123) {
				$_[1]->unpack_properties($_[0], (properties_info)[2]);
			} else {
				$_[1]->unpack_properties($_[0], (properties_info)[3]);
			}
		}
	}
	$_[1]->set_save_marker($_[0], 'load', 1, 'se_actor') if $_[0]->{version} > 123;
}
sub CRandomTask_read {
	$_[1]->set_save_marker($_[0], 'load', 0, 'CRandomTask');
	$_[1]->unpack_properties($_[0], (CRandomTask_info)[0]);
	object_collection_task_read(@_);
	$_[1]->unpack_properties($_[0], (CRandomTask_info)[1..2]);
	$_[1]->set_save_marker($_[0], 'load', 1, 'CRandomTask');
}
sub object_collection_read {
	$_[1]->set_save_marker($_[0], 'load', 0, 'object_collection');
	$_[1]->unpack_properties($_[0], object_collection_info);
	$_[1]->set_save_marker($_[0], 'load', 1, 'object_collection');
}
sub object_collection_task_read {
	$_[1]->set_save_marker($_[0], 'load', 0, 'object_collection');
	$_[1]->unpack_properties($_[0], object_collection_task_info);
	$_[1]->set_save_marker($_[0], 'load', 1, 'object_collection');
}
sub CMinigames_read {
	$_[1]->set_save_marker($_[0], 'load', 0, 'CMinigames');
	$_[1]->unpack_properties($_[0], CMinigames_info);
	$_[1]->set_save_marker($_[0], 'load', 1, 'CMinigames');
}
sub state_write {
	cse_alife_creature_actor::state_write(@_);
	return if $_[0]->{version} < 122;
	$_[1]->set_save_marker($_[0], 'save', 0, 'se_actor') if $_[0]->{version} > 123;
	if ($_[0]->{version} >= 128) {
		$_[1]->pack_properties($_[0], (properties_info)[0]);
	} elsif ($_[0]->{version} >= 122) {
		if ($_[0]->is_save()) {
			CRandomTask_write(@_);
			object_collection_write(@_);
			CMinigames_write(@_);
		} else {
			if ($_[0]->{version} >= 124) {
				$_[1]->pack_properties($_[0], (properties_info)[1]);
			} elsif ($_[0]->{version} >= 123) {
				$_[1]->pack_properties($_[0], (properties_info)[2]);
			} else {
				$_[1]->pack_properties($_[0], (properties_info)[3]);
			}
		}
	}
	$_[1]->set_save_marker($_[0], 'save', 1, 'se_actor') if $_[0]->{version} > 123;
}
sub CRandomTask_write {
	$_[1]->set_save_marker($_[0], 'save', 0, 'CRandomTask');
	$_[1]->pack_properties($_[0], (CRandomTask_info)[0]);
	object_collection_task_write(@_);
	$_[1]->pack_properties($_[0], (CRandomTask_info)[1..2]);
	$_[1]->set_save_marker($_[0], 'save', 1, 'CRandomTask');
}
sub object_collection_write {
	$_[1]->set_save_marker($_[0], 'save', 0, 'object_collection');
	$_[1]->pack_properties($_[0], object_collection_info);
	$_[1]->set_save_marker($_[0], 'save', 1, 'object_collection');
}
sub object_collection_task_write {
	$_[1]->set_save_marker($_[0], 'save', 0, 'object_collection');
	$_[1]->pack_properties($_[0], object_collection_task_info);
	$_[1]->set_save_marker($_[0], 'save', 1, 'object_collection');
}
sub CMinigames_write {
	$_[1]->set_save_marker($_[0], 'save', 0, 'CMinigames');
	$_[1]->pack_properties($_[0], CMinigames_info);
	$_[1]->set_save_marker($_[0], 'save', 1, 'CMinigames');
}
sub state_import {
	cse_alife_creature_actor::state_import(@_);
	if ($_[0]->{version} >= 128) {
		$_[1]->import_properties($_[2], $_[0], (properties_info)[0]);
	} elsif ($_[0]->{version} >= 122) {
		if ($_[0]->is_save()) {
			CRandomTask_import(@_);
			object_collection_import(@_);
			CMinigames_import(@_);
		} else {
			if ($_[0]->{version} >= 124) {
				$_[1]->import_properties($_[2], $_[0], (properties_info)[1]);
			} elsif ($_[0]->{version} >= 123) {
				$_[1]->import_properties($_[2], $_[0], (properties_info)[2]);
			} else {
				$_[1]->import_properties($_[2], $_[0], (properties_info)[3]);
			}
		}
	}
}
sub CRandomTask_import {
	$_[1]->import_properties($_[2], $_[0], (CRandomTask_info)[0]);
	object_collection_task_import(@_);
	$_[1]->import_properties($_[2], $_[0], (CRandomTask_info)[1..2]);
}
sub object_collection_import {
	$_[1]->import_properties($_[2], $_[0], object_collection_info);
}
sub object_collection_task_import {
	$_[1]->import_properties($_[2], $_[0], object_collection_task_info);
}
sub CMinigames_import {
	$_[1]->import_properties($_[2], $_[0], CMinigames_info);
}
sub state_export {
	cse_alife_creature_actor::state_export(@_);
	if ($_[0]->{version} >= 128) {
		$_[1]->export_properties($_[2], $_[0], (properties_info)[0]);
	} elsif ($_[0]->{version} >= 122) {
		if ($_[0]->is_save()) {
			CRandomTask_export(@_);
			object_collection_export(@_);
			CMinigames_export(@_);
		} else {
			if ($_[0]->{version} >= 124) {
				$_[1]->export_properties($_[2], $_[0], (properties_info)[1]);
			} elsif ($_[0]->{version} >= 123) {
				$_[1]->export_properties($_[2], $_[0], (properties_info)[2]);
			} else {
				$_[1]->export_properties($_[2], $_[0], (properties_info)[3]);
			}
		}
	}
}
sub CRandomTask_export {
	$_[1]->export_properties($_[2], $_[0], (CRandomTask_info)[0]);
	object_collection_export(@_);
	$_[1]->export_properties($_[2], $_[0], (CRandomTask_info)[1..2]);
}
sub object_collection_export {
	$_[1]->export_properties($_[2], $_[0], object_collection_info);
}
sub object_collection_task_export {
	$_[1]->export_properties($_[2], $_[0], object_collection_task_info);
}
sub CMinigames_export {
	$_[1]->export_properties($_[2], $_[0], CMinigames_info);
}
sub update_read {
	cse_alife_creature_actor::update_read(@_);
}
sub update_write {
	cse_alife_creature_actor::update_write(@_);
}
sub update_import {
	cse_alife_creature_actor::update_import(@_);
}
sub update_export {
	cse_alife_creature_actor::update_export(@_);
}
sub is_level {
	if ($_[0]->{flags} & FL_LEVEL_SPAWN) {
		return 1;
	}
	return 0;
}
sub is_save {
	if ($_[0]->{flags} & FL_SAVE) {
		return 1;
	}
	return 0;
}
#######################################################################
package se_anomaly_field;
use strict;
use stkutils::debug qw(fail warn);
use constant properties_info => (
	{ name => 'startup',		type => 'u8',	default => 1 },
	{ name => 'update_time_present',type => 'u8',	default => 0 },
	{ name => 'zone_count',		type => 'u8',	default => 0 },
);
sub init {
	cse_alife_space_restrictor::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_space_restrictor::state_read(@_);
$_[1]->resid() == 3 or fail('unexpected size');
	$_[1]->unpack_properties($_[0], (properties_info)[0]);
	$_[0]->{startup} == 0 or fail('unexpected value');
	$_[1]->unpack_properties($_[0], (properties_info)[1]);
	$_[0]->{update_time_present} == 0 or fail('unexpected value');
	$_[1]->unpack_properties($_[0], (properties_info)[2]);
	$_[0]->{zone_count} == 0 or fail('unexpected value');
}
sub state_write {
	cse_alife_space_restrictor::state_write(@_);
	$_[1]->pack_properties($_[0], properties_info);
}
sub state_import {
	cse_alife_space_restrictor::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub state_export {
	cse_alife_space_restrictor::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
}
#######################################################################
package se_level_changer;
use strict;
use constant properties_info => (
	{ name => 'enabled',	type => 'u8',	default => 1 },
	{ name => 'hint',	type => 'sz',	default => 'level_changer_invitation' },
);
sub init {
	cse_alife_level_changer::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_level_changer::state_read(@_);
	if ($_[0]->{version} >= 124) {
		$_[1]->set_save_marker($_[0], 'load', 0, 'se_level_changer');
		$_[1]->unpack_properties($_[0], properties_info);
		$_[1]->set_save_marker($_[0], 'load', 1, 'se_level_changer');
	}
}
sub state_write {
	cse_alife_level_changer::state_write(@_);
	if ($_[0]->{version} >= 124) {
		$_[1]->set_save_marker($_[0], 'save', 0, 'se_level_changer');
		$_[1]->pack_properties($_[0], properties_info);
		$_[1]->set_save_marker($_[0], 'save', 1, 'se_level_changer');
	}
}
sub state_import {
	cse_alife_level_changer::state_import(@_);
	if ($_[0]->{version} >= 124) {
		$_[1]->import_properties($_[2], $_[0], properties_info);
	}
}
sub state_export {
	cse_alife_level_changer::state_export(@_);
	if ($_[0]->{version} >= 124) {
		$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
	}
}
#######################################################################
package se_monster;
use strict;
use stkutils::debug qw(fail warn);
use constant properties_info => (
	{ name => 'under_smart_terrain',	type => 'u8',	default => 0 },
	{ name => 'job_online',				type => 'u8',	default => 2 },
	{ name => 'job_online_condlist',	type => 'sz',	default => 'nil' },
	{ name => 'was_in_smart_terrain',	type => 'u8',	default => 0 },
	{ name => 'squad_id',				type => 'sz',	default => 'nil' },	
	{ name => 'sim_forced_online',		type => 'u8',	default => 0 },
	{ name => 'old_lvid',				type => 'sz',	default => 'nil' },	
	{ name => 'active_section',			type => 'sz',	default => 'nil' },	
);
sub init {
	cse_alife_monster_base::init(@_);
	cse_alife_monster_rat::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	if (($_[0]->{section_name} eq 'm_rat_e') && ($_[0]->{version} <= 104)) {
		cse_alife_monster_rat::state_read(@_);
	} else {
		cse_alife_monster_base::state_read(@_);
		if ($_[0]->{script_version} > 0) {
			if ($_[0]->{script_version} > 10) {
				$_[1]->unpack_properties($_[0], (properties_info)[6..7]);
			} elsif ($_[0]->{script_version} > 3) {
				$_[1]->unpack_properties($_[0], (properties_info)[1]);
				if ($_[0]->{script_version} > 4) {
					if ($_[0]->{job_online} > 2) {
						$_[1]->unpack_properties($_[0], (properties_info)[2]);	
					}
					if ($_[0]->{script_version} > 6) {	
						$_[1]->unpack_properties($_[0], (properties_info)[4]);	
					} else {
						$_[1]->unpack_properties($_[0], (properties_info)[3]);	
					}
					if ($_[0]->{script_version} > 7) {
						$_[1]->unpack_properties($_[0], (properties_info)[5]);	
					}
				}
			} elsif ($_[0]->{script_version} == 2) {
				$_[1]->unpack_properties($_[0], (properties_info)[0]);
			}
		}
	}
}
sub state_write {
	if (($_[0]->{section_name} eq 'm_rat_e') && ($_[0]->{version} <= 104)) {
		cse_alife_monster_rat::state_write(@_);
	} else {
		cse_alife_monster_base::state_write(@_);
		if ($_[0]->{script_version} > 0) {
			if ($_[0]->{script_version} > 10) {
				$_[1]->pack_properties($_[0], (properties_info)[6..7]);
			} elsif ($_[0]->{script_version} > 3) {
				$_[1]->pack_properties($_[0], (properties_info)[1]);
				if ($_[0]->{script_version} > 4) {
					if ($_[0]->{job_online} > 2) {
						$_[1]->pack_properties($_[0], (properties_info)[2]);	
					}
					if ($_[0]->{script_version} > 6) {	
						$_[1]->pack_properties($_[0], (properties_info)[4]);	
					} else {
						$_[1]->pack_properties($_[0], (properties_info)[3]);	
					}
					if ($_[0]->{script_version} > 7) {
						$_[1]->pack_properties($_[0], (properties_info)[5]);	
					}
				}
			} elsif ($_[0]->{script_version} == 2) {
				$_[1]->pack_properties($_[0], (properties_info)[0]);
			}
		}
	}
}
sub state_import {
	if (($_[0]->{section_name} eq 'm_rat_e') && ($_[0]->{version} <= 104)) {
		cse_alife_monster_rat::state_import(@_);
	} else {
		cse_alife_monster_base::state_import(@_);
		$_[1]->import_properties($_[2], $_[0], properties_info);
	}
}
sub state_export {
	if (($_[0]->{section_name} eq 'm_rat_e') && ($_[0]->{version} <= 104)) {
		cse_alife_monster_rat::state_export(@_);
	} else {
		cse_alife_monster_base::state_export(@_);
		$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
	}
}
sub update_read {
	if (($_[0]->{section_name} eq 'm_rat_e') && ($_[0]->{version} <= 104)) {
		cse_alife_monster_rat::update_read(@_);
	} else {
		cse_alife_monster_base::update_read(@_);
	}
}
sub update_write {
	if (($_[0]->{section_name} eq 'm_rat_e') && ($_[0]->{version} <= 104)) {
		cse_alife_monster_rat::update_write(@_);
	} else {
		cse_alife_monster_base::update_write(@_);
	}
}
sub update_import {
	if (($_[0]->{section_name} eq 'm_rat_e') && ($_[0]->{version} <= 104)) {
		cse_alife_monster_rat::update_import(@_);
	} else {
		cse_alife_monster_base::update_import(@_);
	}
}
sub update_export {
	if (($_[0]->{section_name} eq 'm_rat_e') && ($_[0]->{version} <= 104)) {
		cse_alife_monster_rat::update_export(@_);
	} else {
		cse_alife_monster_base::update_export(@_);
	}
}
#######################################################################
package se_respawn;
use strict;
use stkutils::debug qw(fail warn);
use constant properties_info => (
	{ name => 'spawned_obj', type => 'l8u16v', default => [] },
	{ name => 'next_spawn_time_present',	type => 'u8',	default => 0 }, #+#LA
);
sub init {
	cse_alife_smart_zone::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_smart_zone::state_read(@_);
	if ($_[0]->{version} >= 116) {
		$_[1]->unpack_properties($_[0], (properties_info)[0]);
	}
	if (($_[1]->resid() == 1)) {# || ($_[0]->{flags} & stkutils::file::entity::FL_LA == stkutils::file::entity::FL_LA)) {  // temporary
		$_[1]->unpack_properties($_[0], (properties_info)[1]);
		$_[0]->{flags} |= stkutils::file::entity::FL_LA;
	}
}
sub state_write {
	cse_alife_smart_zone::state_write(@_);
	if ($_[0]->{version} >= 116) {
		$_[1]->pack_properties($_[0], (properties_info)[0]);
	}
	if ($_[0]->{flags} & stkutils::file::entity::FL_LA == stkutils::file::entity::FL_LA) {
		$_[1]->pack_properties($_[0], (properties_info)[1]);
	}
}
sub state_import {
	cse_alife_smart_zone::state_import(@_);
	if ($_[0]->{version} >= 116) {
		$_[1]->import_properties($_[2], $_[0], properties_info);
	}
}
sub state_export {
	cse_alife_smart_zone::state_export(@_);
	if ($_[0]->{version} >= 116) {
		$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
	}
}
#######################################################################
package se_sim_faction;
use strict;
use stkutils::debug qw(fail warn);
use constant properties_info => (
	{ name => 'community_player', 			type => 'u8', default => 0  },
	{ name => 'start_position_filled', 		type => 'u8', default => 0  },
	{ name => 'current_expansion_level', 	type => 'u8', default => 0  },	
	{ name => 'last_spawn_time', 			type => 'CTime', default => 0, default => 0},
	{ name => 'squad_target_cache', 		type => 'l8szu16v', default => []  },
	{ name => 'random_tasks', 				type => 'l8u16u16v', default => []  },
	{ name => 'current_attack_quantity',	type => 'l8u16u8v', default => []  },
	{ name => 'squads', 					type => 'sim_squads', default => []  },
);
sub init {
	cse_alife_smart_zone::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_smart_zone::state_read(@_);
	return if $_[0]->{version} < 122;
	$_[1]->set_save_marker($_[0], 'load', 0, 'se_sim_faction') if $_[0]->{version} >= 124;
	$_[1]->unpack_properties($_[0], properties_info);
	$_[1]->set_save_marker($_[0], 'load', 1, 'se_sim_faction') if $_[0]->{version} >= 124;
}
sub state_write {
	cse_alife_smart_zone::state_write(@_);
	return if $_[0]->{version} < 122;
	$_[1]->set_save_marker($_[0], 'save', 0, 'se_sim_faction') if $_[0]->{version} >= 124;
	$_[1]->pack_properties($_[0], properties_info);
	$_[1]->set_save_marker($_[0], 'save', 1, 'se_sim_faction') if $_[0]->{version} >= 124;
}
sub state_import {
	cse_alife_smart_zone::state_import(@_);
	return if $_[0]->{version} < 122;
	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub state_export {
	cse_alife_smart_zone::state_export(@_);
	return if $_[0]->{version} < 122;
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
}
#######################################################################
package sim_squad_scripted;
use strict;
use constant properties_info => (
	{ name => 'current_target_id',	 		type => 'sz', default => '' },
	{ name => 'respawn_point_id', 			type => 'sz', default => '' },
	{ name => 'respawn_point_prop_section', type => 'sz', default => '' },
	{ name => 'smart_id', 					type => 'sz', default => '' },
);
sub init {
	cse_alife_online_offline_group::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_online_offline_group::state_read(@_);
	$_[1]->set_save_marker($_[0], 'load', 0, 'sim_squad_scripted');
	$_[1]->unpack_properties($_[0], properties_info);
	$_[1]->set_save_marker($_[0], 'load', 1, 'sim_squad_scripted');
}
sub state_write {
	cse_alife_online_offline_group::state_write(@_);
	$_[1]->set_save_marker($_[0], 'save', 0, 'sim_squad_scripted');
	$_[1]->pack_properties($_[0], properties_info);
	$_[1]->set_save_marker($_[0], 'save', 1, 'sim_squad_scripted');
}
sub state_import {
	cse_alife_online_offline_group::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub state_export {
	cse_alife_online_offline_group::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
}
###########################################
package se_smart_cover;
use strict;
use constant properties_info => (
	{ name => 'last_description',	type => 'sz',		default => '' },
	{ name => 'loopholes',		type => 'l8szbv',	default => [] }
);
sub init {
	cse_smart_cover::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_smart_cover::state_read(@_);
	if ($_[0]->{version} >=128) {
		$_[1]->unpack_properties($_[0], properties_info);
	}
};
sub state_write {
	cse_smart_cover::state_write(@_);
	if ($_[0]->{version} >=128) {
		$_[1]->pack_properties($_[0], properties_info);
	}
}
sub state_import {
	cse_smart_cover::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub state_export {
	cse_smart_cover::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
}
#######################################################################
package se_smart_terrain;
use strict;
use stkutils::debug qw(fail warn);
use constant FL_LEVEL_SPAWN => 0x01;
use constant combat_manager_properties => (
###CS	
	{ name => 'actor_defence_come',		type => 'u8',	default => 0 },	
	{ name => 'combat_quest',			type => 'sz',	default => 'nil' },		
	{ name => 'task',					type => 'u16',	default => 0xFFFF },	
	{ name => 'see_actor_enemy',		type => 'sz',	default => 'nil' },	
	{ name => 'see_actor_enemy_time',	type => 'complex_time', default => 0},
	{ name => 'squads',					type => 'squads',		default => [] },
	{ name => 'force_online',			type => 'u8',	default => 0 },
	{ name => 'force_online_squads',	type => 'l8szv',	default => [] },
);
use constant cover_manager_properties => (
###CS	
	{ name => 'is_valid',	type => 'u8',	default => 0 },
	{ name => 'covers',		type => 'covers',		default => [] },
);
use constant cs_cop_properties_info => (
	{ name => 'arriving_npc',			type => 'l8u16v',	default => [] },
	{ name => 'npc_info',				type => 'npc_info',		default => [] },
	{ name => 'dead_times',				type => 'times',	default => [] },
	{ name => 'is_base_on_actor_control',	type => 'u8',		default => 0 },
	{ name => 'status',					type => 'u8',		default => 0 },
	{ name => 'alarm_time',				type => 'CTime', default => 0},
	{ name => 'is_respawn_point',		type => 'u8',		default => 0 },
	{ name => 'respawn_count',			type => 'l8szbv',		default => [] },
	{ name => 'last_respawn_update',	type => 'complex_time', default => 0},
	{ name => 'population',				type => 'u8',		default => 0 },
);
use constant soc_properties_info => (
	{ name => 'duration_end',			type => 'CTime', default => 0},
	{ name => 'idle_end',				type => 'CTime', default => 0},
	{ name => 'gulag_working',			type => 'u8',	default => 0 },
	{ name => 'casualities',			type => 'u8',	default => 0 },
	{ name => 'state',					type => 'u8',	default => 0 },
	{ name => 'stateBegin',				type => 'CTime', default => 0},
	{ name => 'population',				type => 'u8',	default => 0 },
	{ name => 'population_comed',		type => 'u8',	default => 0 },
	{ name => 'population_non_exclusive',	type => 'u8',	default => 0 },
	{ name => 'jobs',					type => 'jobs',		default => [] },
	{ name => 'npc_info',				type => 'npc_info',		default => [] },
	{ name => 'population_locked',		type => 'u8',	default => 0 },
);
use constant old_properties_info => (
	{ name => 'gulagN',					type => 'u8', default => 0},
	{ name => 'duration_end',			type => 'CTime', default => 0},
	{ name => 'idle_end',				type => 'CTime', default => 0},
	{ name => 'npc_info',				type => 'npc_info',		default => [] },
	{ name => 'state',					type => 'u8',	default => 0 },
	{ name => 'stateBegin',				type => 'u32', default => 0},
	{ name => 'stateBegin',				type => 'CTime', default => 0},
	{ name => 'casualities',			type => 'u8',	default => 0 },
	{ name => 'jobs',					type => 'l8u32v',	default => [] },
);
sub init {
	cse_alife_smart_zone::init(@_);
	stkutils::file::entity::init_properties($_[0], soc_properties_info);
	stkutils::file::entity::init_properties($_[0], cs_cop_properties_info);
	stkutils::file::entity::init_properties($_[0], cover_manager_properties);
	stkutils::file::entity::init_properties($_[0], combat_manager_properties);
}
sub state_read {
	cse_alife_smart_zone::state_read(@_);
#	return if $_[0]->is_level();
	if ($_[0]->{version} >= 122) {
		state_read_cs_cop(@_);
	} elsif ($_[0]->{version} >= 117) {
		state_read_soc(@_);
	} elsif ($_[0]->{version} >= 95) {
		state_read_old(@_);
	}
}
sub state_read_old {
	$_[1]->unpack_properties($_[0], (old_properties_info)[0..3]);
	if ($_[0]->{script_version} >= 1 && $_[0]->{gulagN} != 0) {
		$_[1]->unpack_properties($_[0], (old_properties_info)[4]);
		$_[1]->unpack_properties($_[0], (old_properties_info)[5]) if $_[0]->{version} < 102;
		$_[1]->unpack_properties($_[0], (old_properties_info)[6]) if $_[0]->{version} >= 102;
		$_[1]->unpack_properties($_[0], (old_properties_info)[7..8]);
	}
}
sub state_read_soc {
	$_[1]->unpack_properties($_[0], (soc_properties_info)[0..2]);
	if ($_[0]->{gulag_working} != 0) {
		$_[1]->unpack_properties($_[0], (soc_properties_info)[3..5]);
		if ($_[0]->{script_version} > 5) {
			$_[1]->unpack_properties($_[0], (soc_properties_info)[6..8]);
		}
		$_[1]->unpack_properties($_[0], (soc_properties_info)[9..10]);
		if ($_[0]->{script_version} > 4) {
			$_[1]->unpack_properties($_[0], (soc_properties_info)[11]);
		}
	}
}
sub state_read_cs_cop {
	$_[1]->set_save_marker($_[0], 'load', 0, 'se_smart_terrain') if $_[0]->{version} > 123;
	if ($_[0]->{version} >= 128) {
		$_[1]->unpack_properties($_[0], (cs_cop_properties_info)[0]) 
	} else {
		CCombat_manager_read(@_);
	}
	$_[1]->unpack_properties($_[0], (cs_cop_properties_info)[1..2]);
	if ($_[0]->{version} > 124) {
		if ($_[0]->{script_version} > 9) {
			$_[1]->unpack_properties($_[0], (cs_cop_properties_info)[3]);
			if ($_[0]->{is_base_on_actor_control} == 1) {
				$_[1]->set_save_marker($_[0], 'load', 0, 'CBaseOnActorControl') if $_[0]->{version} > 123;
				$_[1]->unpack_properties($_[0], (cs_cop_properties_info)[4..5]);
				$_[1]->set_save_marker($_[0], 'load', 1, 'CBaseOnActorControl') if $_[0]->{version} > 123;
			}
		}
		$_[1]->unpack_properties($_[0], (cs_cop_properties_info)[6]);
		if ($_[0]->{is_respawn_point} == 1) {
			$_[1]->unpack_properties($_[0], (cs_cop_properties_info)[7]);
			if ($_[0]->{script_version} > 11) {
				$_[1]->unpack_properties($_[0], (cs_cop_properties_info)[8]);
			}
		}
		$_[1]->unpack_properties($_[0], (cs_cop_properties_info)[9]);
	}
	$_[1]->set_save_marker($_[0], 'load', 1, 'se_smart_terrain') if $_[0]->{version} > 123;
}
sub CCombat_manager_read {
	$_[1]->set_save_marker($_[0], 'load', 0, 'CCombat_manager') if $_[0]->{version} > 123;
	$_[1]->unpack_properties($_[0], combat_manager_properties);
	CCover_manager_read(@_);
	$_[1]->set_save_marker($_[0], 'load', 1, 'CCombat_manager') if $_[0]->{version} > 123;
}
sub CCover_manager_read {
	$_[1]->set_save_marker($_[0], 'load', 0, 'CCover_manager') if $_[0]->{version} > 123;
	$_[1]->unpack_properties($_[0], cover_manager_properties);
	$_[1]->set_save_marker($_[0], 'load', 1, 'CCover_manager') if $_[0]->{version} > 123;
}
sub state_write {
	cse_alife_smart_zone::state_write(@_);
#	return if $_[0]->is_level();
	if ($_[0]->{version} >= 122) {
		state_write_cs_cop(@_);
	} elsif ($_[0]->{version} >= 117) {
		state_write_soc(@_);
	} elsif ($_[0]->{version} >= 95) {
		state_write_old(@_);
	}
}
sub state_write_old {
	$_[1]->pack_properties($_[0], (old_properties_info)[0..3]);
	if ($_[0]->{script_version} >= 1 && $_[0]->{gulagN} != 0) {
		$_[1]->pack_properties($_[0], (old_properties_info)[4]);
		$_[1]->pack_properties($_[0], (old_properties_info)[5]) if $_[0]->{version} < 102;
		$_[1]->pack_properties($_[0], (old_properties_info)[6]) if $_[0]->{version} >= 102;
		$_[1]->pack_properties($_[0], (old_properties_info)[7..8]);
	}
}
sub state_write_soc {
	$_[1]->pack_properties($_[0], (soc_properties_info)[0..2]);
	if ($_[0]->{gulag_working} != 0) {
		$_[1]->pack_properties($_[0], (soc_properties_info)[3..5]);
		if ($_[0]->{script_version} > 5) {
			$_[1]->pack_properties($_[0], (soc_properties_info)[6..8]);
		}
		$_[1]->pack_properties($_[0], (soc_properties_info)[9..10]);
		if ($_[0]->{script_version} > 4) {
			$_[1]->pack_properties($_[0], (soc_properties_info)[11]);
		}
	}
}
sub state_write_cs_cop {
	$_[1]->set_save_marker($_[0], 'save', 0, 'se_smart_terrain') if $_[0]->{version} > 123;
	if ($_[0]->{version} >= 128) {
		$_[1]->pack_properties($_[0], (cs_cop_properties_info)[0]) 
	} else {
		CCombat_manager_write(@_);
	}
	$_[1]->pack_properties($_[0], (cs_cop_properties_info)[1..2]);
	if ($_[0]->{version} > 124) {
		if ($_[0]->{script_version} > 9) {
			$_[1]->pack_properties($_[0], (cs_cop_properties_info)[3]);
			if ($_[0]->{is_base_on_actor_control} == 1) {
				$_[1]->set_save_marker($_[0], 'save', 0, 'CBaseOnActorControl') if $_[0]->{version} > 123;
				$_[1]->pack_properties($_[0], (cs_cop_properties_info)[4..5]);
				$_[1]->set_save_marker($_[0], 'save', 1, 'CBaseOnActorControl') if $_[0]->{version} > 123;
			}
		}
		$_[1]->pack_properties($_[0], (cs_cop_properties_info)[6]);
		if ($_[0]->{is_respawn_point} == 1) {
			$_[1]->pack_properties($_[0], (cs_cop_properties_info)[7]);
			if ($_[0]->{script_version} > 11) {
				$_[1]->pack_properties($_[0], (cs_cop_properties_info)[8]);
			}
		}
		$_[1]->pack_properties($_[0], (cs_cop_properties_info)[9]);
	}
	$_[1]->set_save_marker($_[0], 'save', 1, 'se_smart_terrain') if $_[0]->{version} > 123;
}
sub CCombat_manager_write {
	$_[1]->set_save_marker($_[0], 'save', 0, 'CCombat_manager') if $_[0]->{version} > 123;
	$_[1]->pack_properties($_[0], combat_manager_properties);
	CCover_manager_write(@_);
	$_[1]->set_save_marker($_[0], 'save', 1, 'CCombat_manager') if $_[0]->{version} > 123;
}
sub CCover_manager_write {
	$_[1]->set_save_marker($_[0], 'save', 0, 'CCover_manager') if $_[0]->{version} > 123;
	$_[1]->pack_properties($_[0], cover_manager_properties);
	$_[1]->set_save_marker($_[0], 'save', 1, 'CCover_manager') if $_[0]->{version} > 123;
}
sub state_import {
	cse_alife_smart_zone::state_import(@_);
#	return if $_[0]->is_level();
	if ($_[0]->{version} >= 122) {
		state_import_cs_cop(@_);
	} elsif ($_[0]->{version} >= 117) {
		state_import_soc(@_);
	} elsif ($_[0]->{version} >= 95) {
		state_import_old(@_);
	}
}
sub state_import_old {
	$_[1]->import_properties($_[2], $_[0], (old_properties_info)[0..3]);
	if ($_[0]->{script_version} >= 1 && $_[0]->{gulagN} != 0) {
		$_[1]->import_properties($_[2], $_[0], (old_properties_info)[4]);
		$_[1]->import_properties($_[2], $_[0], (old_properties_info)[5]) if $_[0]->{version} < 102;
		$_[1]->import_properties($_[2], $_[0], (old_properties_info)[6]) if $_[0]->{version} >= 102;
		$_[1]->import_properties($_[2], $_[0], (old_properties_info)[7..8]);
	}
}
sub state_import_soc {
	$_[1]->import_properties($_[2], $_[0], (soc_properties_info)[0..2]);
	if ($_[0]->{gulag_working} != 0) {
		$_[1]->import_properties($_[2], $_[0], (soc_properties_info)[3..5]);
		if ($_[0]->{script_version} > 5) {
			$_[1]->import_properties($_[2], $_[0], (soc_properties_info)[6..8]);
		}
		$_[1]->import_properties($_[2], $_[0], (soc_properties_info)[9..10]);
		if ($_[0]->{script_version} > 4) {
			$_[1]->import_properties($_[2], $_[0], (soc_properties_info)[11]);
		}
	}
}
sub state_import_cs_cop {
	if ($_[0]->{version} >= 128) {
		$_[1]->import_properties($_[2], $_[0], (cs_cop_properties_info)[0]) 
	} else {
		CCombat_manager_import(@_);
	}
	$_[1]->import_properties($_[2], $_[0], (cs_cop_properties_info)[1..2]);
	if ($_[0]->{script_version} > 9) {
		$_[1]->import_properties($_[2], $_[0], (cs_cop_properties_info)[3]);
		if ($_[0]->{is_base_on_actor_control} == 1) {
			$_[1]->import_properties($_[2], $_[0], (cs_cop_properties_info)[4..5]);
		}
	}
	$_[1]->import_properties($_[2], $_[0], (cs_cop_properties_info)[6]);
	if ($_[0]->{is_respawn_point} == 1) {
		$_[1]->import_properties($_[2], $_[0], (cs_cop_properties_info)[7]);
		if ($_[0]->{script_version} > 11) {
			$_[1]->import_properties($_[2], $_[0], (cs_cop_properties_info)[8]);
		}
	}
	$_[1]->import_properties($_[2], $_[0], (cs_cop_properties_info)[9]);
}
sub CCombat_manager_import {
	$_[1]->import_properties($_[2], $_[0], combat_manager_properties);
	CCover_manager_import(@_);
}
sub CCover_manager_import {
	$_[1]->import_properties($_[2], $_[0], cover_manager_properties);
}
sub state_export {
	cse_alife_smart_zone::state_export(@_);
#	return if $_[0]->is_level();
	if ($_[0]->{version} >= 122) {
		state_export_cs_cop(@_);
	} elsif ($_[0]->{version} >= 117) {
		state_export_soc(@_);
	} elsif ($_[0]->{version} >= 95) {
		state_export_old(@_);
	}
}
sub state_export_old {
	$_[1]->export_properties(__PACKAGE__, $_[0], (old_properties_info)[0..3]);
	if ($_[0]->{script_version} >= 1 && $_[0]->{gulagN} != 0) {
		$_[1]->export_properties(undef, $_[0], (old_properties_info)[4]);
		$_[1]->export_properties(undef, $_[0], (old_properties_info)[5]) if $_[0]->{version} < 102;
		$_[1]->export_properties(undef, $_[0], (old_properties_info)[6]) if $_[0]->{version} >= 102;
		$_[1]->export_properties(undef, $_[0], (old_properties_info)[7..8]);
	}
}
sub state_export_soc {
	$_[1]->export_properties(__PACKAGE__, $_[0], (soc_properties_info)[0..2]);
	if ($_[0]->{gulag_working} != 0) {
		$_[1]->export_properties(undef, $_[0], (soc_properties_info)[3..5]);
		if ($_[0]->{script_version} > 5) {
			$_[1]->export_properties(undef, $_[0], (soc_properties_info)[6..8]);
		}
		$_[1]->export_properties(undef, $_[0], (soc_properties_info)[9..10]);
		if ($_[0]->{script_version} > 4) {
			$_[1]->export_properties(undef, $_[0], (soc_properties_info)[11]);
		}
	}
}
sub state_export_cs_cop {
	if ($_[0]->{version} >= 128) {
		$_[1]->export_properties(undef, $_[0], (cs_cop_properties_info)[0]) 
	} else {
		CCombat_manager_export(@_);
	}
	$_[1]->export_properties(undef, $_[0], (cs_cop_properties_info)[1..2]);
	if ($_[0]->{script_version} > 9) {
		$_[1]->export_properties(undef, $_[0], (cs_cop_properties_info)[3]);
		if ($_[0]->{is_base_on_actor_control} == 1) {
			$_[1]->export_properties(undef, $_[0], (cs_cop_properties_info)[4..5]);
		}
	}
	$_[1]->export_properties(undef, $_[0], (cs_cop_properties_info)[6]);
	if ($_[0]->{is_respawn_point} == 1) {
		$_[1]->export_properties(undef, $_[0], (cs_cop_properties_info)[7]);
		if ($_[0]->{script_version} > 11) {
			$_[1]->export_properties(undef, $_[0], (cs_cop_properties_info)[8]);
		}
	}
	$_[1]->export_properties(undef, $_[0], (cs_cop_properties_info)[9]);
}
sub CCombat_manager_export {
	$_[1]->export_properties(undef, $_[0], combat_manager_properties);
	CCover_manager_export(@_);
}
sub CCover_manager_export {
	$_[1]->export_properties(undef, $_[0], cover_manager_properties);
}
sub is_level {
	if ($_[0]->{flags} & FL_LEVEL_SPAWN) {
		return 1;
	}
	return 0;
}
#######################################################################
package se_stalker;
use strict;
use constant FL_HANDLED => 0x20;
use stkutils::debug qw(fail warn);
use constant properties_info => (
	{ name => 'under_smart_terrain',	type => 'u8',	default => 0 },	
	{ name => 'job_online',			type => 'u8',	default => 2 },
	{ name => 'job_online_condlist',	type => 'sz',	default => 'nil' },
	{ name => 'was_in_smart_terrain',	type => 'u8',	default => 0 },
	{ name => 'death_dropped',		type => 'u8',	default => 0 },
	{ name => 'squad_id',		type => 'sz',	default => "nil" },
	{ name => 'sim_forced_online',	type => 'u8',	default => 0 },
	{ name => 'old_lvid',				type => 'sz',	default => 'nil' },	
	{ name => 'active_section',			type => 'sz',	default => 'nil' },	
	{ name => 'pda_dlg_count',        type => 'u8',  default => 0 },     #+#LA
	{ name => 'pda_dlg_update',       type => 's32', default => 0 },     #+#LA
);
sub init {
	cse_alife_human_stalker::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_human_stalker::state_read(@_);
	if (defined $_[0]->{script_version}) {
		if ($_[0]->{script_version} > 10) {
			$_[1]->unpack_properties($_[0], (properties_info)[7..8]);
			$_[1]->unpack_properties($_[0], (properties_info)[4]);
		} elsif ($_[0]->{script_version} > 2) {
			$_[1]->unpack_properties($_[0], (properties_info)[1]);
			if ($_[0]->{script_version} > 4) {
				if ($_[0]->{job_online} > 2) {
					$_[1]->unpack_properties($_[0], (properties_info)[2]);	
				}
				if ($_[0]->{script_version} > 6) {	
					$_[1]->unpack_properties($_[0], (properties_info)[4..5]);	
				} elsif ($_[0]->{script_version} > 5) {	
					$_[1]->unpack_properties($_[0], (properties_info)[3..4]);	
					if (($_[1]->resid() > 0) || ($_[0]->{flags} & stkutils::file::entity::FL_LA == stkutils::file::entity::FL_LA)) {
						$_[1]->unpack_properties($_[0], (properties_info)[9..10]);
						$_[0]->{flags} |= stkutils::file::entity::FL_LA;
					}
				} else {
					$_[1]->unpack_properties($_[0], (properties_info)[3]);	
				}
				if ($_[0]->{script_version} > 7) {
					$_[1]->unpack_properties($_[0], (properties_info)[6]);	
				}
			}
		} elsif ($_[0]->{script_version} == 2) {
			$_[1]->unpack_properties($_[0], (properties_info)[0]);
		}
	}
}
sub state_write {
	cse_alife_human_stalker::state_write(@_);
	if (defined $_[0]->{script_version}) {
		if ($_[0]->{script_version} > 10) {
			$_[1]->pack_properties($_[0], (properties_info)[7..8]);
			$_[1]->pack_properties($_[0], (properties_info)[4]);
		} elsif ($_[0]->{script_version} > 2) {
			$_[1]->pack_properties($_[0], (properties_info)[1]);
			if ($_[0]->{script_version} > 4) {
				if ($_[0]->{job_online} > 2) {
					$_[1]->pack_properties($_[0], (properties_info)[2]);	
				}
				if ($_[0]->{script_version} > 6) {	
					$_[1]->pack_properties($_[0], (properties_info)[4..5]);	
				} elsif ($_[0]->{script_version} > 5) {	
					$_[1]->pack_properties($_[0], (properties_info)[3..4]);	
					if ($_[0]->{flags} & stkutils::file::entity::FL_LA == stkutils::file::entity::FL_LA) {
						$_[1]->pack_properties($_[0], (properties_info)[9..10]);
					}
				} else {
					$_[1]->pack_properties($_[0], (properties_info)[3]);	
				}
				if ($_[0]->{script_version} > 7) {
					$_[1]->pack_properties($_[0], (properties_info)[6]);	
				}
			}
		} elsif ($_[0]->{script_version} == 2) {
			$_[1]->pack_properties($_[0], (properties_info)[0]);
		}
	}
}
sub state_import {
	cse_alife_human_stalker::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub state_export {
	cse_alife_human_stalker::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
}
sub update_read {
	cse_alife_human_stalker::update_read(@_);
}
sub update_write {
	cse_alife_human_stalker::update_write(@_);
}
sub update_import {
	cse_alife_human_stalker::update_import(@_);
}
sub update_export {
	cse_alife_human_stalker::update_export(@_);
}
sub is_handled {return ($_[0]->{flags} & FL_HANDLED)}
#######################################################################
package se_turret_mgun;
use strict;
use constant properties_info => (
	{ name => 'health', type => 'f32', default => 1.0 },
);
sub init {
	cse_alife_helicopter::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_helicopter::state_read(@_);
	$_[1]->unpack_properties($_[0], properties_info);
}
sub state_write {
	cse_alife_helicopter::state_write(@_);
	$_[1]->pack_properties($_[0], properties_info);
}
sub state_import {
	cse_alife_helicopter::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub state_export {
	cse_alife_helicopter::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
}
#######################################################################
package se_zone_anom;
use strict;
use stkutils::debug qw(fail warn);
use constant FL_LEVEL_SPAWN => 0x01;
use constant properties_info => (
	{ name => 'last_spawn_time', type => 'complex_time', default => 0},
);
sub init {
	cse_alife_anomalous_zone::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_anomalous_zone::state_read(@_);
	return if ($_[0]->is_level() && ($_[1]->resid() == 0));
	return if (($_[0]->{version} < 128) && ($_[0]->{section_name} =~ /^zone_field/));
	if ($_[0]->{version} >= 118) {
		$_[1]->unpack_properties($_[0], properties_info);
	}
}
sub state_write {
	cse_alife_anomalous_zone::state_write(@_);
#	return if $_[0]->is_level();
	return if (($_[0]->{version} < 128) && ($_[0]->{section_name} =~ /^zone_field/));
	if ($_[0]->{version} >= 118) {
		$_[1]->pack_properties($_[0], properties_info);
	}
}
sub state_import {
	cse_alife_anomalous_zone::state_import(@_);
#	return if $_[0]->is_level();
	return if (($_[0]->{version} < 128) && ($_[0]->{section_name} =~ /^zone_field/));
	if ($_[0]->{version} >= 118) {
		$_[1]->import_properties($_[2], $_[0], properties_info);
	}
}
sub state_export {
	cse_alife_anomalous_zone::state_export(@_);
#	return if $_[0]->is_level();
	return if (($_[0]->{version} < 128) && ($_[0]->{section_name} =~ /^zone_field/));
	if ($_[0]->{version} >= 118) {
		$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
	}
}
sub update_read {
	cse_alife_anomalous_zone::update_read(@_);
}
sub update_write {
	cse_alife_anomalous_zone::update_write(@_);
}
sub update_import {
	cse_alife_anomalous_zone::update_import(@_);
}
sub update_export {
	cse_alife_anomalous_zone::update_export(@_);
}
sub is_level {
	if ($_[0]->{flags} & FL_LEVEL_SPAWN) {
		return 1;
	}
	return 0;
}
#######################################################################
package se_zone_visual;
use strict;
use stkutils::debug qw(fail warn);
use constant FL_LEVEL_SPAWN => 0x01;
use constant properties_info => (
	{ name => 'last_spawn_time', type => 'complex_time', default => 0},
);
sub init {
	cse_alife_zone_visual::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_zone_visual::state_read(@_);
	return if ($_[0]->is_level() && ($_[1]->resid() == 0));
	if ($_[0]->{version} >= 118) {
		$_[1]->unpack_properties($_[0], properties_info);
	}
}
sub state_write {
	cse_alife_zone_visual::state_write(@_);
	return if $_[0]->is_level();
	if ($_[0]->{version} >= 118) {
		$_[1]->pack_properties($_[0], properties_info);
	}
}
sub state_import {
	cse_alife_zone_visual::state_import(@_);
	return if $_[0]->is_level();
	if ($_[0]->{version} >= 118) {
		$_[1]->import_properties($_[2], $_[0], properties_info);
	}
}
sub state_export {
	cse_alife_zone_visual::state_export(@_);
	return if $_[0]->is_level();
	if ($_[0]->{version} >= 118) {
		$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
	}
}
sub update_read {
	cse_alife_zone_visual::update_read(@_);
}
sub update_write {
	cse_alife_zone_visual::update_write(@_);
}
sub update_import {
	cse_alife_zone_visual::update_import(@_);
}
sub update_export {
	cse_alife_zone_visual::update_export(@_);
}
sub is_level {
	if ($_[0]->{flags} & FL_LEVEL_SPAWN) {
		return 1;
	}
	return 0;
}
#######################################################################
package se_zone_torrid;
use strict;
use stkutils::debug qw(fail warn);
use constant FL_LEVEL_SPAWN => 0x01;
use constant properties_info => (
	{ name => 'last_spawn_time', type => 'complex_time', default => 0},
);
sub init {
	cse_alife_torrid_zone::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_torrid_zone::state_read(@_);
	return if ($_[0]->is_level() && ($_[1]->resid() == 0));
	if ($_[0]->{version} >= 128) {
		$_[1]->unpack_properties($_[0], properties_info);
	}
}
sub state_write {
	cse_alife_torrid_zone::state_write(@_);
	return if $_[0]->is_level();
	if ($_[0]->{version} >= 128) {
		$_[1]->pack_properties($_[0], properties_info);
	}
}
sub state_import {
	cse_alife_torrid_zone::state_import(@_);
	return if $_[0]->is_level();
	if ($_[0]->{version} >= 128) {
		$_[1]->import_properties($_[2], $_[0], properties_info);
	}
}
sub state_export {
	cse_alife_torrid_zone::state_export(@_);
	return if $_[0]->is_level();
	if ($_[0]->{version} >= 128) {
		$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
	}
}
sub update_read {
	cse_alife_torrid_zone::update_read(@_);
}
sub update_write {
	cse_alife_torrid_zone::update_write(@_);
}
sub update_import {
	cse_alife_torrid_zone::update_import(@_);
}
sub update_export {
	cse_alife_torrid_zone::update_export(@_);
}
sub is_level {
	if ($_[0]->{flags} & FL_LEVEL_SPAWN) {
		return 1;
	}
	return 0;
}
#######################################################################
package se_safe;
use strict;
use constant properties_info => (
	{ name => 'items_spawned', type => 'u8', default => 0 },
	{ name => 'safe_locked',   type => 'u8', default => 0 },
	{ name => 'quantity',      type => 'u16', default => 0 }, #+#LA
);
sub init {
	cse_alife_object_physic::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	$_[0]->{flags} |= stkutils::file::entity::FL_LA;
	cse_alife_object_physic::state_read(@_);
	$_[1]->unpack_properties($_[0], properties_info);
};
sub state_write {
	cse_alife_object_physic::state_write(@_);
	$_[1]->pack_properties($_[0], properties_info);
}
sub state_import {
	cse_alife_object_physic::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub state_export {
	cse_alife_object_physic::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
}
###########################################################################
package se_car; #+#LA
use strict;
use constant properties_info => (
	{ name => 'se_car__unk1_u8', type => 'u8', default => 0 },
	{ name => 'se_car__unk2_f32', type => 'f32', default => 1.0 },
	{ name => 'se_car__unk3_u16',	type => 'u16', default => 0 },
);
sub init {
	cse_alife_car::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	$_[0]->{flags} |= stkutils::file::entity::FL_LA;
	cse_alife_car::state_read(@_);
	if ($_[1]->resid() != 0)
	{
		$_[1]->unpack_properties($_[0], properties_info);
	}
};
sub state_write {
	cse_alife_car::state_write(@_);
	$_[1]->pack_properties($_[0], properties_info);
}
sub state_import {
	cse_alife_car::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub state_export {
	cse_alife_car::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
}
#######################################################################
package se_anom_zone;		# LA
use strict;
use stkutils::debug qw(fail warn);
use constant properties_info => (
	{ name => 'af_spawn_id', type => 'u16', default => 0},
	{ name => 'af_spawn_time', type => 'complex_time', default => 0},
);
sub init {
	cse_alife_space_restrictor::init(@_);
	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	$_[0]->{flags} |= stkutils::file::entity::FL_LA;
	cse_alife_space_restrictor::state_read(@_);
	if ($_[1]->resid() != 0)
	{
		$_[1]->unpack_properties($_[0], properties_info);
	}
}
sub state_write {
	cse_alife_space_restrictor::state_write(@_);
	$_[1]->pack_properties($_[0], properties_info);
}
sub state_import {
	cse_alife_space_restrictor::state_import(@_);
	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub state_export {
	cse_alife_space_restrictor::state_export(@_);
	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
}
#######################################################################
package custom_storage;		##### OGSE #######
use strict;
#use constant properties_info => (
#	{ name => 'se_car__unk1_u8', type => 'u8', default => 0 },
#	{ name => 'se_car__unk2_f32', type => 'f32', default => 1.0 },
#	{ name => 'se_car__unk3_u16',	type => 'u16', default => 0 },
#);
sub init {
	cse_alife_dynamic_object::init(@_);
#	stkutils::file::entity::init_properties($_[0], properties_info);
}
sub state_read {
	cse_alife_dynamic_object::state_read(@_);
#	$_[1]->unpack_properties($_[0], properties_info);
};
sub state_write {
	cse_alife_dynamic_object::state_write(@_);
#	$_[1]->pack_properties($_[0], properties_info);
}
sub state_import {
	cse_alife_dynamic_object::state_import(@_);
#	$_[1]->import_properties($_[2], $_[0], properties_info);
}
sub state_export {
	cse_alife_dynamic_object::state_export(@_);
#	$_[1]->export_properties(__PACKAGE__, $_[0], properties_info);
}
#######################################################################
1;