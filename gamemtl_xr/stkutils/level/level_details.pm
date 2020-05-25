# Module for handling level.details stalker files
# Update history:
#	27/08/2012 - fix code for new fail() syntax, fix bugs
##################################################
package fsd_mesh;
use strict;
sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;
	return $self;
}
sub read {
	my ($self, $packet) = @_;
	($self->{shader}, 
	$self->{textures}, 
	$self->{flags}, 
	$self->{min_scale}, 
	$self->{max_scale}, 
	$self->{number_vertices}, 
	$self->{number_indices}) = $packet->unpack('Z*Z*VffVV');
	for (my $i = 0; $i < $self->{number_vertices}; $i++) {
		my $vertex = {};
		@{$vertex->{position}} = $packet->unpack('f3', 12);
		($vertex->{u},$vertex->{v}) = $packet->unpack('ff', 8);
		push @{$self->{vertices}}, $vertex;
	}
	@{$self->{indices}} = $packet->unpack("v$self->{number_indices}", 2 * $self->{number_indices});
	$self->calculate_corners();
}
sub write {
	my ($self, $packet) = @_;
	$packet->pack('Z*Z*VffVV', $self->{shader}, $self->{textures}, $self->{flags}, $self->{min_scale}, $self->{max_scale}, $self->{number_vertices}, $self->{number_indices});
	foreach my $vertex (@{$self->{vertices}}) {
		$packet->pack('f3ff', @{$vertex->{position}}, $vertex->{u}, $vertex->{v});
	}
	$packet->pack("v$self->{number_indices}", @{$self->{indices}});
}
sub calculate_corners {
	my $self = shift;
	$self->{min} = {};
	$self->{max} = {};
	$self->{min}->{u} = 5192;
	$self->{min}->{v} = 5192;
	$self->{max}->{u} = 0;
	$self->{max}->{v} = 0;
	foreach my $vert (@{$self->{vertices}}) {
		$self->{min}->{u} = $vert->{u} if $vert->{u} < $self->{min}->{u};
		$self->{min}->{v} = $vert->{v} if $vert->{v} < $self->{min}->{v};
		$self->{max}->{u} = $vert->{u} if $vert->{u} > $self->{max}->{u};
		$self->{max}->{v} = $vert->{v} if $vert->{v} > $self->{max}->{v};
	}
}
sub import {print "fsd_mesh::import - not implemented";}
sub export {print "fsd_mesh::export - not implemented";}
#######################################
package fsd_slot;
use strict;
use constant properties_info => (
	{ name => 'data',		type => 'ha2'},
	{ name => 'palette',	type => 'u16v4'},
);
sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;
	return $self;
}
sub read {$_[1]->unpack_properties($_[0], properties_info);}
sub write {$_[1]->pack_properties($_[0], properties_info);}
sub import {print "fsd_slot::import - not implemented";}
sub export {print "fsd_slot::export - not implemented";}
#######################################
package stkutils::level::level_details;
use strict;
use stkutils::data_packet;
use stkutils::chunked;
use stkutils::debug qw(fail);

use constant FSD_HEADER		=> 0x0;
use constant FSD_MESHES		=> 0x1;
use constant FSD_SLOTS		=> 0x2;

sub new {
	my $class = shift;
	my $self = {};
	$self->{data} = '';
	$self->{data} = $_[0] if defined $_[0];
	$self->{slot_data} = '';
	bless $self, $class;
	return $self;
}
sub read {
	my ($self, $mode) = @_;
	my $cf = stkutils::chunked->new($self->{data}, 'data');
	while (1) {
		my ($id, $size) = $cf->r_chunk_open();
		defined $id or last;
		SWITCH: {
			$id == FSD_HEADER && do { $self->read_header($cf); last SWITCH; };
			$id == FSD_MESHES && do { $self->read_meshes($cf); last SWITCH; };
			$id == FSD_SLOTS && do { $self->read_slots($cf, $mode); last SWITCH; };
			fail ('unexpected chunk '.$id);
		}
		$cf->r_chunk_close();
	}
	$cf->close();
}
sub write {
	my ($self, $mode) = @_;
	my $cf = stkutils::chunked->new('', 'data');
	$self->write_meshes($cf);
	$self->write_slots($cf, $mode);
	$self->write_header($cf);
	$self->{data} = $cf->data();
	$cf->close();
}
sub read_header {
	my ($self, $cf) = @_;	
	print "	read header...\n";
	my $packet = stkutils::data_packet->new($cf->r_chunk_data());
	($self->{version}, 
	$self->{object_count}, 
	$self->{offset_x}, 
	$self->{offset_z}, 
	$self->{size_x}, 
	$self->{size_z}) = $packet->unpack('VVllVV');
	fail ('data left '.$packet->resid()) unless $packet->resid() == 0;
}
sub write_header {
	my ($self, $cf) = @_;	
	my $packet = stkutils::data_packet->new();
	$packet->pack('VVllVV', $self->{version}, $self->{object_count}, $self->{offset_x}, $self->{offset_z}, $self->{size_x}, $self->{size_z});
	$cf->w_chunk(FSD_HEADER, $packet->data());
}
sub read_meshes {
	my ($self, $cf) = @_;	
	print "	read meshes...\n";
	while (1) {
		my ($id, $size) = $cf->r_chunk_open();
		defined $id or last;
		my $packet = stkutils::data_packet->new($cf->r_chunk_data());
		my $mesh = fsd_mesh->new();
		$mesh->read($packet);
		push @{$self->{meshes}}, $mesh;
		$cf->r_chunk_close();
		fail ('data left '.$packet->resid()) unless $packet->resid() == 0;
	}
}
sub write_meshes {
	my ($self, $cf) = @_;
	my $i = 0;
	$cf->w_chunk_open(FSD_MESHES);
	foreach my $mesh (@{$self->{meshes}}) {
		my $packet = stkutils::data_packet->new();
		$mesh->write($packet);
		$cf->w_chunk($i++, $packet->data());
	}
	$cf->w_chunk_close();
}
sub read_slots {
	my ($self, $cf, $mode) = @_;	
	print "	read slots...\n";
	if ($mode and ($mode eq 'full')) {
		my $packet = stkutils::data_packet->new($cf->r_chunk_data());
		my $count = $packet->length() / 16;
		for (my $i = 0; $i < $count; $i++) {
			my $slot = fsd_slot->new();
			$slot->read($packet);
			push @{$self->{slots}}, $slot;
		}
		fail ('data left '.$packet->resid()) unless $packet->resid() == 0;
	} else {
		$self->{slot_data} = $cf->r_chunk_data();
	}
}
sub write_slots {
	my ($self, $cf, $mode) = @_;
	my $i = 0;
	$cf->w_chunk_open(FSD_SLOTS);
	if ($mode and ($mode eq 'full')) {
		foreach my $slot (@{$self->{slots}}) {
			my $packet = stkutils::data_packet->new();
			$slot->write($packet);
			$cf->w_chunk($i++, $packet->data());
		}
	} else {
		$cf->w_chunk_data(${$self->{slot_data}});
	}
	$cf->w_chunk_close();
}
sub data {return $_[0]->{data}};
1;