# Module for handling level.ai stalker files
# Update history:
#	27/08/2012 - fix code for new fail() syntax
##################################################
package stkutils::level::level_ai;
use strict;
use stkutils::chunked;
use stkutils::data_packet;
use stkutils::debug qw(fail);
sub new {
	my $class = shift;
	my $self = {};
	$self->{data} = '';
	$self->{data} = $_[0] if defined $_[0];
	$self->{vertex_data} = '';
	$self->{header} = ai_header->new();
	bless $self, $class;
	return $self;
}
sub read {
	my $self = shift;
	my ($mode) = @_;
	my $switch = unpack('V', substr(${$self->{data}}, 0, 4));
	if ($switch > 6) {
		if ($switch > 7) {
			$self->{header}->read(stkutils::data_packet->new(\substr(${$self->{data}}, 0, 56)));
			$self->{vertex_data} = \substr(${$self->{data}}, 56);
		} else {
			$self->{header}->read(stkutils::data_packet->new(\substr(${$self->{data}}, 0, 40)));
			$self->{vertex_data} = \substr(${$self->{data}}, 40);
		}
	} else {
		fail('unsupported version');
	}
	if (defined $mode && $mode eq 'full') {
		$self->_read_vertices();		
	}
}	
sub _read_vertices {
	my $self = shift;
	my $packet = stkutils::data_packet->new($self->{vertex_data});
	for (my $i = 0; $i < $self->{header}->{vertex_count}; $i++) {
		my $vertex = ai_vertex->new($self->{header}->{version});
		$vertex->read($packet);
		push @{$self->{vertices}}, $vertex;
	}		
}
sub write {
	my $self = shift;
	my ($mode) = @_;
	my $packet = stkutils::data_packet->new();
	$self->{header}->write($packet);
	if (defined $mode && $mode eq 'full') {
		$self->_write_vertices();	
	}
	my $data = $packet->data().${$self->{vertex_data}};
	$self->{data} = \$data;
}	
sub _write_vertices {
	my $self = shift;
	my $packet = stkutils::data_packet->new();
	foreach my $vertex (@{$self->{vertices}}) {
		$vertex->write($packet);
	}		
	$self->{vertex_data} = \$packet->data();	
}
######################################################
package ai_header;
use strict;
use constant header => (
	{ name => 'version',		type => 'u32' },
	{ name => 'vertex_count',	type => 'u32' },
	{ name => 'cell_size',	type => 'f32' },
	{ name => 'factor_y',	type => 'f32' },
	{ name => 'bbox_min',	type => 'f32v3' },
	{ name => 'bbox_max',	type => 'f32v3' },
	{ name => 'level_guid',		type => 'guid' },
);
sub new {
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}
sub read {
	$_[1]->unpack_properties($_[0], (header)[0..5]);
	if ($_[0]->{version} > 7) {
		$_[1]->unpack_properties($_[0], (header)[6]);
	}
}
sub write {
	$_[1]->pack_properties($_[0], (header)[0..5]);
	if ($_[0]->{version} > 7) {
		$_[1]->pack_properties($_[0], (header)[6]);
	}
}
sub export {
	my $self = shift;
	my ($fh) = @_;

	print $fh "version = $self->{version}\n";
	print $fh "vertex_count = $self->{vertex_count}\n";
	print $fh "cell_size = $self->{cell_size}\n";
	print $fh "factor_y = $self->{factor_y}\n";
	print $fh "bbox_min = $self->{bbox_min}\n";
	print $fh "bbox_max = $self->{bbox_max}\n";
	print $fh "level_guid = $self->{level_guid}\n" if $self->{version} > 7;
	print $fh "\n";
}
sub import {
	my $self = shift;
	my ($fh) = @_;

	$self->{version} = $fh->value('header', 'version');
	$self->{vertex_count} = $fh->value('header', 'vertex_count');
	$self->{cell_size} = $fh->value('header', 'cell_size');
	$self->{factor_y} = $fh->value('header', 'factor_y');
	$self->{bbox_min} = $fh->value('header', 'bbox_min');
	$self->{bbox_max} = $fh->value('header', 'bbox_max');
	$self->{level_guid} = $fh->value('header', 'level_guid');

}
######################################################
package ai_vertex;
use strict;
use constant vertex => (
	{ name => 'data',		type => 'ha1' },
	{ name => 'cover',		type => 'u16' },
	{ name => 'low_cover',		type => 'u16' },
	{ name => 'plane',		type => 'u16' },
	{ name => 'packed_xz_lo',		type => 'u16' },
	{ name => 'packed_xz_hi',		type => 'u8' },
	{ name => 'packed_y',		type => 'u16' },
);
sub new {
	my $class = shift;
	my $self = {};
	$self->{version} = $_[0];
	bless($self, $class);
	return $self;
}
sub read {
	$_[1]->unpack_properties($_[0], (vertex)[0..1]);
	if ($_[0]->{version} > 9) {
		$_[1]->unpack_properties($_[0], (vertex)[2]);
	}
	$_[1]->unpack_properties($_[0], (vertex)[3..6]);
}
sub write {
	$_[1]->pack_properties($_[0], (vertex)[0..1]);
	if ($_[0]->{version} > 9) {
		$_[1]->pack_properties($_[0], (vertex)[2]);
	}
	$_[1]->pack_properties($_[0], (vertex)[3..6]);
}
sub export {
	my $self = shift;
	my ($fh) = @_;
	print "not implemented\n";
}
sub import {
	my $self = shift;
	my ($fh, $i) = @_;
	print "not implemented\n";
}
1;
######################################################