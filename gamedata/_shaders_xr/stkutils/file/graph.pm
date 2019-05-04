# Module for handling stalker *.graph files
# Update history:
#	27/08/2012 - fix data for new fail() syntax
##########################################################
package gg_header;
use strict;
use constant header_1472 => (							#12 байт
	{ name => 'version',		type => 'u32' },
	{ name => 'vertex_count',	type => 'u32' },
	{ name => 'level_count',	type => 'u32' },
);
use constant header_1935 => (							#20 байт
	{ name => 'version',		type => 'u32' },
	{ name => 'level_count',	type => 'u32' },
	{ name => 'vertex_count',	type => 'u32' },
	{ name => 'edge_count',		type => 'u32' },
	{ name => 'level_point_count',	type => 'u32' },
);
use constant header_2215 => (							#36 байт
	{ name => 'version',		type => 'u32' },
	{ name => 'level_count',	type => 'u32' },
	{ name => 'vertex_count',	type => 'u32' },
	{ name => 'edge_count',		type => 'u32' },
	{ name => 'level_point_count',	type => 'u32' },
	{ name => 'guid',	type => 'guid' },
);
use constant header_SOC => (							#28 байт
	{ name => 'version',		type => 'u8' },
	{ name => 'vertex_count',	type => 'u16' },
	{ name => 'edge_count',		type => 'u32' },
	{ name => 'level_point_count',	type => 'u32' },
	{ name => 'guid',		type => 'guid' },
	{ name => 'level_count',	type => 'u8' },
);
sub new {
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}
sub read {
	if ($_[2] eq '1469' or $_[2] eq '1472') {
		$_[1]->unpack_properties($_[0], header_1472);
	} elsif ($_[2] eq '1510' or $_[2] eq '1935') {
		$_[1]->unpack_properties($_[0], header_1935);	
	} elsif ($_[2] eq '2215') {
		$_[1]->unpack_properties($_[0], header_2215);	
	} else {
		$_[1]->unpack_properties($_[0], header_SOC);		
	}
}
sub write {
	if ($_[2] eq '1469' or $_[2] eq '1472') {
		$_[1]->pack_properties($_[0], header_1472);
	} elsif ($_[2] eq '1510' or $_[2] eq '1935') {
		$_[1]->pack_properties($_[0], header_1935);	
	} elsif ($_[2] eq '2215') {
		$_[1]->pack_properties($_[0], header_2215);	
	} else {
		$_[1]->pack_properties($_[0], header_SOC);		
	}
}
sub export {
	my $self = shift;
	my ($fh, $lg) = @_;
	print $fh "version = $self->{version}\n";
	print $fh "level_count = $self->{level_count}\n";
	print $fh "vertex_count = $self->{vertex_count}\n";
	print $fh "level_point_count = $self->{level_point_count}\n" if (!$lg && defined $self->{level_point_count});
	print $fh "edge_count = $self->{edge_count}\n" if (defined $self->{edge_count});
	print $fh "\n";
}
#######################################################################
package gg_level;
use strict;
use constant level_1469 => (
	{ name => 'level_name',		type => 'sz' },
	{ name => 'offset',		type => 'f32v3' },
);
use constant level_1472 => (
	{ name => 'level_name',		type => 'sz' },
	{ name => 'offset',		type => 'f32v3' },
	{ name => 'level_id',		type => 'u32' },
);
use constant level_1935 => (
	{ name => 'level_name',		type => 'sz' },
	{ name => 'offset',		type => 'f32v3' },
	{ name => 'level_id',		type => 'u32' },
	{ name => 'section_name',	type => 'sz' },
);
use constant level_2215 => (
	{ name => 'level_name',		type => 'sz' },
	{ name => 'offset',		type => 'f32v3' },
	{ name => 'level_id',		type => 'u32' },
	{ name => 'section_name',	type => 'sz' },
	{ name => 'guid',	type => 'guid' },
);
use constant level_SOC => (
	{ name => 'level_name',		type => 'sz' },
	{ name => 'offset',		type => 'f32v3' },
	{ name => 'level_id',		type => 'u8' },
	{ name => 'section_name',	type => 'sz' },
	{ name => 'guid',	type => 'guid' },
);
sub new {
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}
sub read {
	if ($_[2] eq '1469') {
		$_[1]->unpack_properties($_[0], level_1469);
		if ($_[0]->{level_name} eq 'level2_test') {
			$_[0]->{level_id} = 0;
		} elsif ($_[0]->{level_name} eq 'occ_part') {
			$_[0]->{level_id} = 1;
		} else {
			$_[0]->{level_id} = 2;
		}
	} elsif ($_[2] eq '1472' or $_[2] eq '1510') {
		$_[1]->unpack_properties($_[0], level_1472);
	} elsif ($_[2] eq '1935') {
		$_[1]->unpack_properties($_[0], level_1935);	
	} elsif ($_[2] eq '2215') {
		$_[1]->unpack_properties($_[0], level_2215);	
	} else {
		$_[1]->unpack_properties($_[0], level_SOC);		
	}
}
sub write {
	if ($_[2] eq '1469') {
		$_[1]->pack_properties($_[0], level_1469);
	} elsif ($_[2] eq '1472' or $_[2] eq '1510') {
		$_[1]->pack_properties($_[0], level_1472);
	} elsif ($_[2] eq '1935') {
		$_[1]->pack_properties($_[0], level_1935);	
	} elsif ($_[2] eq '2215') {
		$_[1]->pack_properties($_[0], level_2215);	
	} else {
		$_[1]->pack_properties($_[0], level_SOC);		
	}
}
sub export {
	my $self = shift;
	my ($fh, $lg) = @_;
	print $fh "level_name = $self->{level_name}\n";
	print $fh "level_id = $self->{level_id}\n" if (!$lg && defined $self->{level_id});
	print $fh "section_name = $self->{section_name}\n" if (!$lg && defined $self->{section_name});
	print $fh "offset = ", join(',', @{$self->{offset}}), "\n\n";
}
#######################################################################
package gg_vertex;
use strict;
use constant vertex_1472 => (
	{ name => 'level_point',	type => 'f32v3' },
	{ name => 'game_point',		type => 'f32v3' },
	{ name => 'level_id',	type => 'u8' },
	{ name => 'level_vertex_id',	type => 'u24' },
	{ name => 'vertex_type',	type => 'u8v4' },
	{ name => 'edge_count',	type => 'u8' },
	{ name => 'edge_offset',	type => 'u24' },
);
use constant vertex_1935 => (
	{ name => 'level_point',	type => 'f32v3' },
	{ name => 'game_point',		type => 'f32v3' },
	{ name => 'level_id',	type => 'u8' },
	{ name => 'level_vertex_id',	type => 'u24' },
	{ name => 'vertex_type',	type => 'u8v4' },
	{ name => 'edge_count',	type => 'u8' },		
	{ name => 'edge_offset',	type => 'u24' },	
	{ name => 'level_point_count',		type => 'u8' },	
	{ name => 'level_point_offset',	type => 'u24' },
);
use constant vertex_SOC => (
	{ name => 'level_point',	type => 'f32v3' },
	{ name => 'game_point',		type => 'f32v3' },
	{ name => 'level_id',	type => 'u8' },
	{ name => 'level_vertex_id',	type => 'u24' },
	{ name => 'vertex_type',	type => 'u8v4' },
	{ name => 'edge_offset',	type => 'u32' },
	{ name => 'level_point_offset',	type => 'u32' },
	{ name => 'edge_count',		type => 'u8' },
	{ name => 'level_point_count',	type => 'u8' },
);
sub new {
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}
sub read {
	my $ver = $_[2]->{gg_version};
	my $eOffset = $_[2]->{edges_offset};
	my $lpOffset = $_[2]->{level_points_offset};
	if ($ver eq '1469' or $ver eq '1472') {
		$_[1]->unpack_properties($_[0], vertex_1472);
	} elsif ($ver eq '1510' or $ver eq '1935' or $ver eq '2215') {
		$_[1]->unpack_properties($_[0], vertex_1935);
	} else {
		$_[1]->unpack_properties($_[0], vertex_SOC);
	}
	if ($ver eq '1469' or $ver eq '1472' or $_[2]->level_graph()) {
		$_[0]->{edge_index} = ($_[0]->{edge_offset} - $eOffset) / ($_[2]->edge_block_size());
	} else {
		$_[0]->{edge_index} = ($_[0]->{edge_offset} - $eOffset) / ($_[2]->edge_block_size());
		$_[0]->{level_point_index} = ($_[0]->{level_point_offset} - $eOffset - $lpOffset) / 0x14;
	}	
}
sub write {
	my $ver = $_[2]->{gg_version};
	my $eOffset = $_[2]->{edges_offset};
	my $lpOffset = $_[2]->{level_points_offset};
	if ($ver eq '1469' or $ver eq '1472') {
		$_[1]->pack_properties($_[0], vertex_1472);
	} elsif ($ver eq '1510' or $ver eq '1935' or $ver eq '2215') {
		$_[0]->{edge_offset} = $_[2]->edge_block_size() * ($_[0]->{edge_index}) + $eOffset;
		if (!$_[2]->level_graph()) {
			$_[0]->{level_point_offset} = 0x14 * $_[0]->{level_point_index} + $eOffset + $lpOffset;
		} else {
			$_[0]->{level_point_offset} = 0;
			$_[0]->{level_point_count} = 0;
		}
		$_[1]->pack_properties($_[0], vertex_1935);
	} else {
		$_[0]->{edge_offset} = $_[2]->edge_block_size() * ($_[0]->{edge_index}) + $eOffset;
		if (!$_[2]->level_graph()) {
			$_[0]->{level_point_offset} = 0x14 * $_[0]->{level_point_index} + $eOffset + $lpOffset;
		} else {
			$_[0]->{level_point_offset} = 0;
			$_[0]->{level_point_count} = 0;
		}
		$_[1]->pack_properties($_[0], vertex_SOC);
	}
}
sub export {
	my $self = shift;
	my ($fh, $lg) = @_;
	print $fh "level_point = ", join(',', @{$self->{level_point}}), "\n";
	print $fh "game_point = ", join(',', @{$self->{game_point}}), "\n" if (!$lg);
	print $fh "level_id = $self->{level_id}\n" if (!$lg);
	print $fh "level_vertex_id = $self->{level_vertex_id}\n";
	print $fh "vertex_type = ", join(',', @{$self->{vertex_type}}), "\n";
	print $fh "level_points = $self->{level_point_index}, $self->{level_point_count}\n" if defined $self->{level_point_count};
	print $fh "edges = $self->{edge_index}, $self->{edge_count}\n\n";
}
#######################################################################
package gg_edge;
use strict;
use constant edge_builds => (
	{ name => 'game_vertex_id',	type => 'u32' },
	{ name => 'distance',		type => 'f32' },
);
use constant edge_SOC => (
	{ name => 'game_vertex_id',	type => 'u16' },
	{ name => 'distance',		type => 'f32' },
);
sub new {
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}
sub read {
	if ($_[2] eq 'soc' or $_[2] eq 'cop') {
		$_[1]->unpack_properties($_[0], edge_SOC);
	} else {
		$_[1]->unpack_properties($_[0], edge_builds);
	}
}
sub write {
	if ($_[2] eq 'soc' or $_[2] eq 'cop') {
		$_[1]->pack_properties($_[0], edge_SOC);
	} else {
		$_[1]->pack_properties($_[0], edge_builds);
	}
}
sub export {
	my $self = shift;
	my ($fh) = @_;
	print $fh "game_vertex_id = $self->{game_vertex_id}\n";
	print $fh "distance = $self->{distance}\n\n";
}
#######################################################################
package gg_level_point;
use strict;
use constant properties_info => (
	{ name => 'point',		type => 'f32v3' },
	{ name => 'level_vertex_id',	type => 'u32' },
	{ name => 'distance',		type => 'f32' },
);
sub new {
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}
sub read {
	$_[1]->unpack_properties($_[0], properties_info);
}
sub write {
	$_[1]->pack_properties($_[0], properties_info);
}
sub export {
	my $self = shift;
	my ($fh) = @_;

	print $fh "point = ", join(',', @{$self->{point}}), "\n";
	print $fh "level_vertex_id = $self->{level_vertex_id}\n";
	print $fh "distance = $self->{distance}\n\n";
}
#######################################################################
package gg_cross_table;
use strict;
use constant properties_info => (
	{ name => 'size',			type => 'u32' },
	{ name => 'version',		type => 'u32' },
	{ name => 'cell_count',		type => 'u32' },
	{ name => 'vertex_count',	type => 'u32' },
	{ name => 'level_guid',		type => 'guid' },
	{ name => 'game_guid',		type => 'guid' },
);
sub new {
	my $class = shift;
	my $self = {};
	$self->{cells} = {};
	bless($self, $class);
	return $self;
}
sub read {
	$_[1]->unpack_properties($_[0], properties_info);
}
sub export {
	my $self = shift;
	my ($fh) = @_;

	print $fh "version = $self->{version}\n";
	print $fh "cell_count = $self->{cell_count}\n";
	print $fh "vertex_count = $self->{vertex_count}\n";
	print $fh "level_guid = $self->{level_guid}\n";
	print $fh "game_guid = $self->{game_guid}\n";
	print $fh "\n";
}
#######################################################################
package stkutils::file::graph;
use strict;
use IO::File;
use stkutils::data_packet;
use stkutils::debug qw(fail);

sub new {
	my $class = shift;
	my $self = {};
	$self->{header} = gg_header->new();
	$self->{data} = '';
	$self->{data} = $_[0] if defined $_[0];
	$self->{level_by_id} = {};
	$self->{level_by_guid} = {};
	$self->{lp_offsets} = {};
	$self->{lp_counts} = {};
	$self->{ct_size} = {};
	$self->{ct_offset} = {};
	$self->{raw_cross_tables} = {};
	$self->{raw_vertices} = '';
	$self->{raw_edges} = '';
	$self->{raw_level_points_all} = '';
	$self->{raw_cross_tables_all} = '';
	$self->{is_level_graph} = 0;
	bless($self, $class);
	return $self;
}
sub check_graph_version {
	my $self = shift;
	$self->{gg_version} = '1510';
	my $switch = unpack('V', substr(${$self->{data}}, 0, 4));
	if ($switch <= 8) {
		if ($switch == 8) {
			$self->{gg_version} = '2215';
		} elsif ($switch == 3) {
			my $edge_count = unpack('V', substr(${$self->{data}}, 12, 4));
			if ($edge_count > 50000) {
				$self->{gg_version} = '1469';
			}		
		}
	} else {
		my $version = unpack('C', substr(${$self->{data}}, 0, 1));
		if ($version == 8) {
			$self->{gg_version} = 'soc';
		} elsif ($version > 8) {
			$self->{gg_version} = 'cop';
		} else {
			fail('wrong graph format');
		}
	}
}
sub decompose {
	my $self = shift;
	print "reading game graph...\n";
	if (!defined $self->{gg_version}) {
		$self->check_graph_version();
	}
	$self->read_header(\substr(${$self->{data}}, 0, $self->header_size()));
	$self->{level_size} = 0x1000;
	$self->{level_size} = length(${$self->{data}}) if length(${$self->{data}}) < 0x1000;
	$self->read_levels(\substr(${$self->{data}}, 0, $self->{level_size}));
	$self->{raw_vertices} = \substr(${$self->{data}}, $self->{vertices_offset}, $self->{edges_offset});
	if ($self->{gg_version} eq '1469' || $self->{gg_version} eq '1472' || $self->level_graph()) {
		$self->{raw_edges} = \substr(${$self->{data}}, $self->{vertices_offset} + $self->{edges_offset});
		if ($self->{gg_version} eq '1469' && !$self->level_graph() && length(${$self->{data}}) != $self->{vertices_offset} + $self->{edges_offset}) {
			$self->error_handler('1472');
			return;
		}
	} else {
		if ($self->{gg_version} eq '1510' && !$self->level_graph() && length(${$self->{data}}) != $self->{vertices_offset} + $self->{edges_offset} + $self->{level_points_offset} + $self->{header}->{level_point_count} * 0x14) {
			$self->error_handler('1935');
			return;
		}
		$self->{raw_edges} = \substr(${$self->{data}}, $self->{vertices_offset} + $self->{edges_offset}, $self->{level_points_offset});
		if ($self->{gg_version} eq 'cop') {
			$self->{raw_level_points_all} = \substr(${$self->{data}}, $self->{vertices_offset} + $self->{edges_offset} + $self->{level_points_offset}, $self->{cross_tables_offset});
			$self->split_ct_block();
		} else {
			$self->{raw_level_points_all} = \substr(${$self->{data}}, $self->{vertices_offset} + $self->{edges_offset} + $self->{level_points_offset});
		}
	}
}
sub split_lp_block {
	my $self = shift;
	if ($self->{header}->{level_count} == 1) {
		$self->{raw_level_points}{@{$self->{levels}}[0]->{level_name}} = $self->{raw_level_points_all};
		return;
	};
	foreach my $level (@{$self->{levels}}) {
		if ($level->{level_point_offset} + $level->{level_point_count} * 0x14 < length(${$self->{raw_level_points_all}})) {
			$self->{raw_level_points}{$level->{level_name}} = \substr(${$self->{raw_level_points_all}}, $level->{level_point_offset}, $level->{level_point_count} * 0x14)
		} else {
			$self->{raw_level_points}{$level->{level_name}} = \substr(${$self->{raw_level_points_all}}, $level->{level_point_offset})
		}
	}	
}
sub split_ct_block {
	my $self = shift;
	if ($self->{header}->{level_count} == 1) {
		$self->{raw_cross_tables}{@{$self->{levels}}[0]->{level_name}} = $self->{raw_cross_tables_all};
		return;
	};
	$self->{raw_cross_tables_all} = \substr(${$self->{data}}, $self->{vertices_offset} + $self->{edges_offset} + $self->{level_points_offset} + $self->{cross_tables_offset});
	my $com_offset = $self->{vertices_offset} + $self->{edges_offset} + $self->{level_points_offset} + $self->{cross_tables_offset};
	$self->read_ct_offsets();
	foreach my $level (@{$self->{levels}}) {
		if ($self->{ct_offset}{$level->{level_name}} + $self->{ct_size}{$level->{level_name}} < length(${$self->{raw_cross_tables_all}})) {
			$self->{raw_cross_tables}{$level->{level_name}} = \substr(${$self->{raw_cross_tables_all}}, $self->{ct_offset}{$level->{level_name}}, $self->{ct_size}{$level->{level_name}})
		} else {
			$self->{raw_cross_tables}{$level->{level_name}} = \substr(${$self->{raw_cross_tables_all}}, $self->{ct_offset}{$level->{level_name}})
		}
	}
}
sub read_header {
	my $self = shift;
	print "	reading header...\n";
	$self->{header}->read(stkutils::data_packet->new($_[0]), $self->{gg_version});
	$self->{edges_offset} = $self->{header}->{vertex_count} * $self->vertex_block_size();
	if (not ($self->{gg_version} eq '1469' or $self->{gg_version} eq '1472')) {
		$self->{level_points_offset} = $self->{header}->{edge_count} * $self->edge_block_size();
	}
	if ($self->{gg_version} eq 'cop') {
		$self->{cross_tables_offset} = $self->{header}->{level_point_count} * 0x14;
	}
}
sub read_levels {
	my $self = shift;
	print "	reading levels...\n";	
	my $packet = stkutils::data_packet->new(\substr(${$_[0]}, $self->header_size()));
	for (my $i = 0; $i < $self->{header}->{level_count}; $i++) {
		my $level = gg_level->new();			
		$level->read($packet, $self->{gg_version});
		push @{$self->{levels}}, $level;
	}	
	foreach my $level (@{$self->{levels}}) {
		$self->{level_by_id}{$level->{level_id}} = $level;
		$self->{level_by_name}{$level->{level_name}} = $level;
	}
	$self->{vertices_offset} = $self->{level_size} - $packet->resid();
}
sub read_vertices {
	my $self = shift;
	print "	reading vertices...\n";	
	my $packet = stkutils::data_packet->new($self->{raw_vertices});
	for (my $i = 0; $i < $self->{header}->{vertex_count}; $i++) {
		my $vertex = gg_vertex->new();
		$vertex->read($packet, $self);
		push @{$self->{vertices}}, $vertex;
	}
	my $game_vertex_id = 0;
	my $level_id = -1;
	my $level_count = 1;
	$self->{level_by_guid}{$self->{header}->{vertex_count}} = '_level_unknown';
	foreach my $vertex (@{$self->{vertices}}) {
		### fill some level properties
		if ($vertex->{level_id} != $level_id) {
			my $level_curr = $self->{level_by_id}{$vertex->{level_id}};
			my $level_prev = $self->{level_by_id}{$level_id} if $level_id > 0;
			$level_curr->{vertex_index} = $game_vertex_id;
			$level_curr->{edge_index} = $vertex->{edge_index};
			$level_curr->{level_point_index} = $vertex->{level_point_index};
			$level_curr->{level_point_offset} = $vertex->{level_point_offset} - $self->{edges_offset} - $self->{level_points_offset};
			### maintain last level ($vertex->{level_id} != $level_id can't be true)
			if ($level_id > 0) {
				$level_prev->{vertex_count} = $game_vertex_id - $level_prev->{vertex_index};
				$level_prev->{edge_count} = $level_curr->{edge_index} - $level_prev->{edge_index};
				$level_prev->{level_point_count} = $level_curr->{level_point_index} - $level_prev->{level_point_index};
			}
			if ($self->{header}->{level_count} == 1 or $self->{header}->{level_count} == $level_count) {
				$level_curr->{vertex_count} = $self->{header}->{vertex_count} - $level_curr->{vertex_index};
				$level_curr->{edge_count} = $self->{header}->{edge_count} - $level_curr->{edge_index};
				$level_curr->{level_point_count} = $self->{header}->{level_point_count} - $level_curr->{level_point_index};
				$self->{level_by_guid}{$game_vertex_id} = $level_curr->{level_name};
				return;
			}
			$level_count++;
			$level_id = $vertex->{level_id};
			$self->{level_by_guid}{$game_vertex_id} = $level_curr->{level_name};
		}
		$game_vertex_id++;
	}
}
sub read_edges {
	my $self = shift;
	print "	reading edges...\n";	
	my $packet = stkutils::data_packet->new($self->{raw_edges});
	my $edge_count = 0;
	if ($self->{gg_version} eq '1469' || $self->{gg_version} eq '1472' || $self->level_graph()) {
		$edge_count = ($packet->resid())/$self->edge_block_size();
	} else {
		$edge_count = $self->{header}->{edge_count};
	}
	for (my $i = 0; $i < $edge_count; $i++) {
		my $edge = gg_edge->new();
		$edge->read($packet, $self->{gg_version});
		push @{$self->{edges}}, $edge;
	}	
}
sub read_level_points {
	my $self = shift;
	return if $self->{raw_level_points_all} eq '';
	my $packet = stkutils::data_packet->new($self->{raw_level_points_all});
	print "	reading level points...\n";	
	for (my $i = 0; $i < $self->{header}->{level_point_count}; $i++) {
		my $level_point = gg_level_point->new();
		$level_point->read($packet);
		push @{$self->{level_points}}, $level_point;
	}
}
sub read_lp_offsets {
	my $self = shift;
	$self->{lp_offsets} = {};
	$self->{lp_counts} = {};
	foreach my $vertex (@{$self->{vertices}}) {
		my $level = $self->{level_by_id}{$vertex->{level_id}};
		if (!defined $self->{lp_offsets}{$$level->{level_name}}) {
			$self->{lp_offsets}{$$level->{level_name}} = $vertex->{level_point_offset};    ####оффсеты идут с начала файла!
			$self->{lp_counts}{$$level->{level_name}} = $vertex->{level_point_count};
			my $var = $self->{offset_for_ct} + $self->{lp_offsets}{$$level->{level_name}};
		} else {
			$self->{lp_counts}{$$level->{level_name}} += $vertex->{level_point_count};
		}
	}
}
sub read_cross_tables {
	my $self = shift;
	return if $self->{header}->{version} < 4;
	print "	reading cross tables...\n";
	foreach my $level (@{$self->{levels}}) {
		my $cross_table = stkutils::level_gct->new($self->{raw_cross_tables}{$level->{level_name}});
		$cross_table->read('full');
		$cross_table->{level_name} = $level->{level_name};
		push @{$self->{cross_tables}}, $cross_table;
	}
}
sub read_ct_offsets {
	my $self = shift;
	my $offset = 0;
	my $data = ${$self->{raw_cross_tables_all}};
	my $len = length($data);
	foreach my $level (@{$self->{levels}}) {
		($self->{ct_size}{$level->{level_name}}) = unpack('V', substr($data, 0, 0x04));
		$self->{ct_offset}{$level->{level_name}} = $offset;   		####оффсеты идут с начала блока кросс-таблиц!
		$offset += $self->{ct_size}{$level->{level_name}};
		if (length($data) > $self->{ct_size}{$level->{level_name}}) {
			$data = substr($data, $self->{ct_size}{$level->{level_name}});
		}
	}		
}
sub load_cross_tables {
	my $self = shift;
	return if ($self->{gg_version} eq 'cop' or $self->{header}->{version} < 4);
	print "	loading cross tables...\n";
	foreach my $level (@{$self->{levels}}) {
		my $fh = IO::File->new('levels\\'.$level->{level_name}.'\level.gct', 'r') or next;
		binmode $fh;
		my $data = '';
		$fh->read($data, ($fh->stat())[7]);
		$fh->close();
		$self->{raw_cross_tables}{$level->{level_name}} = \$data;
	}
}
sub save_cross_tables {
	my $self = shift;
	return if ($self->{gg_version} eq 'cop' or $self->{header}->{version} < 4);
	print "	saving cross tables...\n";
	foreach my $level (@{$self->{levels}}) {
		my $fn = 'levels\\'.$level->{level_name}.'\level.gct';
		rename $fn, $fn.'.bak' or unlink $fn.'bak' and rename $fn, $fn.'.bak';
		my $fh = IO::File->new($fn, 'w') or fail("$! $fn\n");
		binmode $fh;
		fail('cannot find cross table for level '.$level->{level_name}) unless defined $self->{raw_cross_tables}{$level->{level_name}};
		$fh->write(${$self->{raw_cross_tables}{$level->{level_name}}}, length(${$self->{raw_cross_tables}{$level->{level_name}}}));
		$fh->close();
	}
}
sub compose {
	my $self = shift;
	my $h = $self->write_header();
	my $l = $self->write_levels();
	my $hlve = $h.$l.${$self->{raw_vertices}}.${$self->{raw_edges}};
	if (($self->{gg_version} ne '1469') && ($self->{gg_version} ne '1472') && (!$self->level_graph())) {
		if (defined $self->{raw_level_points}) {
			my $lp_data = '';
			foreach my $level (@{$self->{levels}}) {
				$lp_data .= ${$self->{raw_level_points}{$level->{level_name}}};
			}	
			$self->{raw_level_points_all} = \$lp_data;	
		}
		$hlve .= ${$self->{raw_level_points_all}};		
		if ($self->{gg_version} eq 'cop') {
			my $ct_data = '';
			foreach my $level (@{$self->{levels}}) {
				$ct_data .= ${$self->{raw_cross_tables}{$level->{level_name}}};
			}	
			$self->{raw_cross_tables_all} = \$ct_data;				
			$hlve .= ${$self->{raw_cross_tables_all}};
		}
	}
	$self->{data} = \$hlve;
}
sub write_header {
	my $self = shift;
	print "	writing header...\n";
	my $packet = stkutils::data_packet->new();
	$self->{header}->write($packet, $self->{gg_version});
	return $packet->data();
}
sub write_levels {
	my $self = shift;
	print "	writing levels...\n";
	my $packet = stkutils::data_packet->new();
	foreach my $level (@{$self->{levels}}) {
		$level->write($packet, $self->{gg_version});
	}
	return $packet->data();
}
sub write_vertices {
	my $self = shift;
	print "	writing vertices...\n";
	my $packet = stkutils::data_packet->new();
	foreach my $vertex (@{$self->{vertices}}) {
		$vertex->write($packet, $self);
	}
	$self->{raw_vertices} = \$packet->data();
}
sub write_edges {
	my $self = shift;
	print "	writing edges...\n";
	my $packet = stkutils::data_packet->new();
	foreach my $edge (@{$self->{edges}}) {
		$edge->write($packet, $self->{gg_version});
	}
	$self->{raw_edges} = \$packet->data();
}
sub write_level_points {
	my $self = shift;
	return if ($self->{gg_version} eq '1469' or $self->{gg_version} eq '1472');
	print "	writing level points...\n";
	my $packet = stkutils::data_packet->new();
	foreach my $lpoint (@{$self->{level_points}}) {
		$lpoint->write($packet, $self->{gg_version});
	}
	$self->{raw_level_points_all} = \$packet->data();	
}
sub write_cross_tables {
	my $self = shift;
	return if $self->{header}->{version} < 4;
	print "	writing cross tables...\n";
	foreach my $ct (@{$self->{cross_tables}}) {
		$ct->write('full');
		$self->{raw_cross_tables}{$ct->{level_name}} = $ct->{data};
	}
}
sub export_header {
	my $self = shift;
	my ($fh) = @_;
	print "	exporting header...\n";
	print $fh "[header]\n";
	my $lg = $self->level_graph();
	$self->{header}->export($fh, $lg);
}
sub export_levels {	
	my $self = shift;
	my ($fh) = @_;
	print "	exporting levels...\n";
	my $i = 0;
	my $lg = $self->level_graph();
	foreach my $level (@{$self->{levels}}) {
		print $fh "[level_$i]\n";
		$level->export($fh, $lg);
		$i++;
	}
}
sub export_vertices {	
	my $self = shift;
	my ($fh) = @_;
	my $i = 0;
	my $lg = $self->level_graph();
	print "	exporting vertices...\n";
	foreach my $vertex (@{$self->{vertices}}) {
		print $fh "[vertex_$i]\n";
		$vertex->export($fh, $lg);
		$i++;
	}
}
sub export_edges {	
	my $self = shift;
	my ($fh) = @_;
	my $i = 0;
	print "	exporting edges...\n";
	foreach my $edge (@{$self->{edges}}) {
		print $fh "[edge_$i]\n";
		$edge->export($fh);
		$i++;
	}
}
sub export_level_points {	
	my $self = shift;
	my ($fh) = @_;
	return if $self->{raw_level_points_all} eq '';
	my $i = 0;
	print "	exporting level points...\n";
	foreach my $level_point (@{$self->{level_points}}) {
		print $fh "[level_point_$i]\n";
		$level_point->export($fh);
		$i++;
	}
}
sub export_cross_tables {	
	my $self = shift;
	my ($fh) = @_;
	my $i = 0;
	print "	exporting cross tables...\n";
	foreach my $cross_table (@{$self->{cross_tables}}) {
		print $fh "[cross_table_$i]\n";
		$cross_table->export($fh);
		print $fh "level_name = $cross_table->{level_name}\n";
		for (my $j = 0; $j < $cross_table->{cell_count}; $j++) {
			my $graph_id = $cross_table->{cells}->{$j}{graph_id};
			my $distance = $cross_table->{cells}->{$j}{distance};
			print $fh "node$j = $graph_id, $distance\n";
		}			
		$i++;
	}
}
sub show_links {
	my $self = shift;
	my ($fn) = @_;
	return if $self->{header}->{level_count} == 1;
	my %level_by_id = ();
	foreach my $level (@{$self->{levels}}) {
		$level_by_id{$level->{level_id}} = $level;
	}
	my $vid = 0;
	my $fh = IO::File->new($fn, 'a') if defined $fn;
	foreach my $vertex (@{$self->{vertices}}) {
		for (my $i = 0; $i < $vertex->{edge_count}; $i++) {
			my $edge = $self->{edges}[$vertex->{edge_index} + $i];
			my $vid2 = $edge->{game_vertex_id};
			my $vertex2 = $self->{vertices}[$vid2];
			if ($vertex->{level_id} != $vertex2->{level_id}) {
				my $level = $level_by_id{$vertex->{level_id}};
				my $level2 = $level_by_id{$vertex2->{level_id}};
				my $name = $level->{level_name};
				my $name2 = $level2->{level_name};
				if (defined $fn) {				
					printf $fh "%s (%d) --%5.2f--> %s (%d)\n", $name, $vid, $edge->{distance}, $name2, $vid2;		
#					print $fh "$name ($vid) --  $edge->{distance}  --> $name2 ($vid2)\n";
				} else {
					printf "%s (%d) --%5.2f--> %s (%d)\n", $name, $vid, $edge->{distance}, $name2, $vid2;		
				}				
			}
		}
		$vid++;
	}
	$fh->close() if defined $fn;
}
sub show_guids {
	my $self = shift;
	my ($fn) = @_;
	return if $self->{header}->{level_count} == 1;
	my %level_by_id = ();
	foreach my $level (@{$self->{levels}}) {
		$level_by_id{$level->{level_id}} = \$level;
	}
	my $game_vertex_id = 0;
	my $level_id = -1;
	my $fh = IO::File->new($fn, 'a') if defined $fn;
	foreach my $vertex (@{$self->{vertices}}) {
		if ($vertex->{level_id} != $level_id) {
			my $level = $level_by_id{$vertex->{level_id}};
			if (defined $fn) {
				print $fh "\n[$$level->{level_name}]\ngvid0 = $game_vertex_id\nid = $vertex->{level_id}\n";
			} else {
				print "{ gvid0 => $game_vertex_id,		name => '$$level->{level_name}' },\n";			
			}
			$level_id = $vertex->{level_id};
		}
		$game_vertex_id++;
	}
	$fh->close() if defined $fn;
}
sub gvid_by_name {
	my $self = shift;
	my %rev = reverse %{$self->{level_by_guid}};
	foreach my $level (sort {$b cmp $a} keys %rev) {
		if ($_[0] eq $level) {
			return $rev{$level};
		}
	}
	return undef;
}
sub level_name {
	my $self = shift;
	return '_level_unknown' unless defined $_[0];
	foreach my $guid (sort {$b <=> $a} keys %{$self->{level_by_guid}}) {
		if ($_[0] >= $guid) {
			return $self->{level_by_guid}{$guid};
		}
	}
	return '_level_unknown';
}
sub level_id {		# returns level id by level name
	my $self = shift;
	return 65535 unless defined $_[0];
	foreach my $id (keys %{$self->{level_by_id}}) {
		if ($self->{level_by_id}{$id}->{level_name} eq $_[0]) {
			return $id;
		}
	}
	return 65535;
}
sub level_name_by_id {		# returns level name by level id
	my $self = shift;
	return '_level_unknown' unless defined $_[0];
	foreach my $id (keys %{$self->{level_by_id}}) {
		if ($_[0] == $id) {
			return $self->{level_by_id}{$id}->{level_name};
		}
	}
	return '_level_unknown';
}
sub edge_block_size {
	my $ver = $_[0]->{gg_version};
	if ($ver eq 'soc' or $ver eq 'cop') {
		return 0x06;
	} else {
		return 0x08;
	}
}
sub vertex_block_size {
	my $ver = $_[0]->{gg_version};
	if ($ver eq '1469' or $ver eq '1472') {
		return 0x24;
	} elsif ($ver eq '1510' or $ver eq '1935' or $ver eq '2215') {
		return 0x28;
	} else {
		return 0x2a;
	}
}
sub header_size {
	my $ver = $_[0]->{gg_version};
	if ($ver eq '1469' or $ver eq '1472') {
		return 0x0C;
	} elsif ($ver eq '1510' or $ver eq '1935') {
		return 0x14;
	} elsif ($ver eq '2215') {
		return 0x24;
	} else {
		return 0x1C;
	}
}
sub level_graph {
	return $_[0]->{is_level_graph} == 1;
}
sub is_old {return ($_[0]->{gg_version} eq '1469' or $_[0]->{gg_version} eq '1472')}
sub error_handler {
	my $self = shift;
	print "Graph seems to be a $_[0] type. Reading again...\n";
	$self->{gg_version} = $_[0];
	@{$self->{levels}} = ();
	$self->decompose();
}
1;
#####################################################################