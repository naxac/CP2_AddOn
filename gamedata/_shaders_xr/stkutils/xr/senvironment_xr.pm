# S.T.A.L.K.E.R. senvironment.xr handling module
# Update history: 
#	28/08/2012 - initial release
##############################################
package stkutils::xr::senvironment_xr;
use strict;
use stkutils::debug qw(fail);
use stkutils::data_packet;
use stkutils::ini_file;
use stkutils::utils qw(get_filelist);
use File::Path qw(mkpath);

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
	my ($fh) = @_;
	
	$fh = stkutils::chunked->new($self->{data}, 'data') if $#_ == -1;
	while (1) {
		my ($index, $size) = $fh->r_chunk_open();
		defined($index) or last;
		my $packet = stkutils::data_packet->new($fh->r_chunk_data());
		my $obj = {};
		($obj->{Version},
		$obj->{Name},
		$obj->{Room},
		$obj->{RoomHF},
		$obj->{RoomRolloffFactor},
		$obj->{DecayTime},
		$obj->{DecayHFRatio},
		$obj->{Reflections},
		$obj->{ReflectionsDelay},
		$obj->{Reverb},
		$obj->{ReverbDelay},
		$obj->{Size},
		$obj->{Diffusion},
		$obj->{AirAbsorptionHF}) = $packet->unpack ('VZ*f12');
		($obj->{PresetID}) = $packet->unpack ('V') if ($obj->{Version} > 3);
		fail('there is some data left in packet: '.$packet->resid()) unless $packet->resid() == 0;
		$fh->r_chunk_close();
		push @{$self->{envs}}, $obj;
	}
	$fh->close() if $#_ == -1;
}
sub write {
	my $self = shift;
	my ($fh) = @_;
	
	$fh = stkutils::chunked->new('', 'data') if $#_ == -1;
	my $i = 0;
	foreach my $obj (sort {$a->{Name} cmp $b->{Name}} @{$self->{envs}}) {
		my $packet = stkutils::data_packet->new();
		$packet->pack('VZ*f12', $obj->{Version}, $obj->{Name}, $obj->{Room}, $obj->{RoomHF}, $obj->{RoomRolloffFactor}, $obj->{DecayTime}, $obj->{DecayHFRatio}, $obj->{Reflections}, $obj->{ReflectionsDelay}, $obj->{Reverb}, $obj->{ReverbDelay}, $obj->{Size}, $obj->{Diffusion}, $obj->{AirAbsorptionHF});
		$packet->pack('V', $obj->{PresetID}) if ($obj->{Version} > 3);	
		$fh->w_chunk($i++, $packet->data());
	}
	$self->{data} = $fh->data();
	$fh->close() if $#_ == -1;
}
sub export {
	my $self = shift;
	my ($out) = @_;
	
	mkpath($out);
	chdir $out or fail ("$out: $!\n");
	foreach my $object (@{$self->{envs}}) {
		my $fn = $object->{Name}.'.ltx';
		my $ini = IO::File->new($fn, 'w') or fail("$fn: $!\n");
		print $ini "[header]\n";
		print $ini "name = $object->{Name}\n";
		print $ini "version = $object->{Version}\n\n";
		print $ini "[environment]\n";
		printf $ini "size = %.5g\n", $object->{Size};
		printf $ini "diffusion = %.5g\n", $object->{Diffusion};
		if ($object->{Version} > 3) {
			print $ini "preset_id = $object->{PresetID}\n\n";
		} else {
			print $ini "\n";
		}
		print $ini "[room]\n";
		printf $ini "room = %.5g\n", $object->{Room};
		printf $ini "room_hf = %.5g\n\n",$object->{RoomHF};
		print $ini "[distance_effects]\n";
		printf $ini "room_rolloff_factor = %.5g\n", $object->{RoomRolloffFactor};
		printf $ini "air_absorption_hf = %.5g\n\n", $object->{AirAbsorptionHF};
		print $ini "[decay]\n";
		printf $ini "decay_time = %.5g\n", $object->{DecayTime};
		printf $ini "decay_hf_ratio = %.5g\n\n", $object->{DecayHFRatio};
		print $ini "[reflections]\n";
		printf $ini "reflections = %.5g\n", $object->{Reflections};
		printf $ini "reflections_delay = %.5g\n\n", $object->{ReflectionsDelay};
		print $ini "[reverb]\n";
		printf $ini "reverb = %.5g\n", $object->{Reverb};
		printf $ini "reverb_delay = %.5g\n", $object->{ReverbDelay};
		$ini->close();
	}
}
sub my_import {
	my $self = shift;
	my ($out) = @_;

	my $list = get_filelist($out, 'ltx');
	foreach my $file (@$list) {
		my $ini = stkutils::ini_file->new($file, 'r') or fail("$file: $!\n");
		my $obj = {};
		$obj->{Version} = $ini->value('header', 'version');
		$obj->{Name} = $ini->value('header', 'name');
		$obj->{Size} = $ini->value('environment', 'size');
		$obj->{Diffusion} = $ini->value('environment', 'diffusion');
		$obj->{AirAbsorptionHF} = $ini->value('distance_effects', 'air_absorption_hf');
		$obj->{PresetID} = $ini->value('environment', 'preset_id') if ($obj->{Version} > 3);
		$obj->{Room} = $ini->value('room', 'room');
		$obj->{RoomHF} = $ini->value('room', 'room_hf');
		$obj->{RoomRolloffFactor} = $ini->value('distance_effects', 'room_rolloff_factor');
		$obj->{DecayTime} = $ini->value('decay', 'decay_time');
		$obj->{DecayHFRatio} = $ini->value('decay', 'decay_hf_ratio');
		$obj->{Reflections} = $ini->value('reflections', 'reflections');
		$obj->{ReflectionsDelay} = $ini->value('reflections', 'reflections_delay');
		$obj->{Reverb} = $ini->value('reverb', 'reverb');
		$obj->{ReverbDelay} = $ini->value('reverb', 'reverb_delay');
		push @{$self->{envs}}, $obj;
		$ini->close();
	}
}
#################################################################################
1;