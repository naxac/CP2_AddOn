# Module for handling level.gct stalker files
# Update history:
#	26/08/2012 - fix code for new fail() syntax
##################################################
package stkutils::level::level_gct;
use strict;
use stkutils::chunked;
use stkutils::data_packet;
use stkutils::debug qw(fail);
use constant CT_HEADER => 0x0;
use constant CT_DATA => 0x1;
sub new {
	my $class = shift;
	my $self = {};
	$self->{data} = '';
	$self->{data} = $_[0] if defined $_[0];
	$self->{cell_data} = '';
	$self->{header} = ct_header->new();
	bless $self, $class;
	return $self;
}
sub set_version {$_[0]->{header}->{version} = $_[1]}
sub get_data {return $_[0]->{data}}
sub read {
	my $self = shift;
	my ($mode) = @_;
	my $switch = unpack('V', substr(${$self->{data}}, 0, 4));
	if ($switch == 0) { 									#soc and pre-soc old format
		my $dh = stkutils::chunked->new($self->{data}, 'data');
		if ($dh->find_chunk(CT_HEADER)) {
			$self->{header}->read(stkutils::data_packet->new($dh->r_chunk_data()));
			$dh->close_found_chunk();
		} else {
			fail('cannot find header chunk');
		}
		if ($dh->find_chunk(CT_DATA)) {
			$self->{cell_data} = $dh->r_chunk_data();
			if (defined $mode && $mode eq 'full') {
				$self->_read_cells();		
			}
			$dh->close_found_chunk();
		} else {
			fail('cannot find data chunk');
		}
		$dh->close();
	} else {													#3120 and next
		my $header_data = substr(${$self->{data}}, 4, 44);
		$self->{header}->read(stkutils::data_packet->new(\$header_data));
		$self->{cell_data} = \substr(${$self->{data}}, 48);
		if (defined $mode && $mode eq 'full') {
			$self->_read_cells();
		}
	}
}	
sub _read_cells {
	my $self = shift;
	my $packet = stkutils::data_packet->new($self->{cell_data});
	$packet->length() % 0x6 == 0 or fail('bad CT_DATA chunk');
	for (my $i = 0; $i < $self->{header}->{cell_count}; $i++) {
		my $cell = ct_cell->new();
		$cell->read($packet);
		push @{$self->{cells}}, $cell;
	}		
}
sub write {
	my $self = shift;
	my ($mode) = @_;
	my $packet = stkutils::data_packet->new();
	$self->{header}->write($packet);
	if (defined $mode && $mode eq 'full') {
		$self->_write_cells();	
	}
	if ($self->{header}->{version} < 9) { 							#soc and pre-soc old format
		my $dh = stkutils::chunked->new('', 'data');
		$dh->w_chunk(CT_HEADER, $packet->data());
		$dh->w_chunk(CT_DATA, ${$self->{cell_data}});
		$self->{data} = $dh->data();
		$dh->close();
	} else {														#3120 and next
		my $data = $packet->data().${$self->{cell_data}};
		my $size = length($data) + 4;
		$data = pack('V', $size).$data;
		$self->{data} = \$data;
	}
}	
sub _write_cells {
	my $self = shift;
	my $packet = stkutils::data_packet->new();
	foreach my $cell (@{$self->{cells}}) {
		$cell->write($packet);
	}		
	$self->{cell_data} = \$packet->data();	
}
######################################################
package ct_header;
use strict;
use constant header => (
	{ name => 'version',		type => 'u32' },
	{ name => 'cell_count',		type => 'u32' },
	{ name => 'vertex_count',	type => 'u32' },
	{ name => 'level_guid',		type => 'guid' },
	{ name => 'game_guid',		type => 'guid' },
);
sub new {
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}
sub read {
	$_[1]->unpack_properties($_[0], (header)[0..2]);
	if ($_[0]->{version} > 7) {
		$_[1]->unpack_properties($_[0], (header)[3..4]);
	}
}
sub write {
	$_[1]->pack_properties($_[0], (header)[0..2]);
	if ($_[0]->{version} > 7) {
		$_[1]->pack_properties($_[0], (header)[3..4]);
	}
}
sub export {
	my $self = shift;
	my ($fh) = @_;

	print $fh "version = $self->{version}\n";
	print $fh "cell_count = $self->{cell_count}\n";
	print $fh "vertex_count = $self->{vertex_count}\n";
	print $fh "level_guid = $self->{level_guid}\n" if $self->{version} > 7;
	print $fh "game_guid = $self->{game_guid}\n" if $self->{version} > 7;
	print $fh "\n";
}
sub import {
	my $self = shift;
	my ($fh) = @_;

	$self->{version} = $fh->value('header', 'version');
	$self->{cell_count} = $fh->value('header', 'cell_count');
	$self->{vertex_count} = $fh->value('header', 'vertex_count');
	$self->{level_guid} = $fh->value('header', 'level_guid');
	$self->{game_guid} = $fh->value('header', 'game_guid');

}
######################################################
package ct_cell;
use strict;
use constant cell => (
	{ name => 'game_vertex_id',		type => 'u16' },
	{ name => 'distance',		type => 'f32' },
);
sub new {
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}
sub read {
	$_[1]->unpack_properties($_[0], cell);
}
sub write {
	$_[1]->pack_properties($_[0], cell);
}
sub export {
	my $self = shift;
	my ($fh) = @_;

	print $fh "game_vertex_id = $self->{game_vertex_id}\n";
	print $fh "distance = $self->{distance}\n";
	print $fh "\n";
}
sub import {
	my $self = shift;
	my ($fh, $i) = @_;

	$self->{game_vertex_id} = $fh->value($i, 'game_vertex_id');
	$self->{distance} = $fh->value($i, 'distance');
}
1;
######################################################