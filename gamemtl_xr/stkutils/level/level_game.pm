# Module for handling level.game stalker files
# Update history:
#	27/08/2012 - fix code for new fail() syntax
##################################################
package stkutils::level::level_game;
use strict;
use stkutils::debug qw(fail);
sub new {
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}
sub read {
	my $self = shift;
	my ($cf) = @_;
	while (1) {
		my ($index, $size) = $cf->r_chunk_open();
		defined($index) or last;
		if ($index == 0) {
			$self->{name} = unpack('Z*', ${$cf->r_chunk_data()});
		} elsif ($index == 1) {
			while (1) {
				($index, $size) = $cf->r_chunk_open();
				defined($index) or last;
				if ($index == 0) {
					$size == 4 or fail('point count size mismatch');
					$self->{point_count} = unpack('V', ${$cf->r_chunk_data()});
				} elsif ($index == 1) {
					$self->read_points($cf);
				} elsif ($index == 2) {
					$self->read_links($cf);
				}
				$cf->r_chunk_close();
			}
		} else {
			fail('unexpected index '.$index);
		}
		$cf->r_chunk_close();
	}
}
sub read_points {
	my $self = shift;
	my ($cf) = @_;
	while (1) {
		my ($index, $size) = $cf->r_chunk_open();
		defined($index) or last;
		while (1) {
			($index, $size) = $cf->r_chunk_open();
			defined($index) or last;
			if ($index == 0) {
				$size == 4 or fail('point index size mismatch');
				my $point_index = unpack('V', ${$cf->r_chunk_data()});
			} elsif ($index == 1) {
				my %point;
				(
					$point{name},
					$point{position}[0],
					$point{position}[1],
					$point{position}[2],
					$point{flags},
					$point{level_vertex_id},
					$point{game_vertex_id},
				) = unpack('Z*f3VVv', ${$cf->r_chunk_data()});
				push @{$self->{points}}, \%point;
			}
			$cf->r_chunk_close();
		}
		$cf->r_chunk_close();
	}
}
sub read_links {
	my $self = shift;
	my ($cf) = @_;
	my $packet = stkutils::data_packet->new($cf->r_chunk_data());
	while (1) {
		$packet->resid() > 0 or last;
		my ($from, $to_count) = $packet->unpack('VV', 8);
		my $point = $self->{points}[$from];
		while ($to_count--) {
			my %link;
			($link{to}, $link{weight}) = $packet->unpack('Vf', 8);
			push @{$point->{links}}, \%link;
		}
	}
}
sub write {
	my $self = shift;
	my ($cf) = @_;

	$cf->w_chunk(0, pack('Z*', $self->{name}));
	$cf->w_chunk_open(1);
		$cf->w_chunk(0, pack('V', $#{$self->{points}} + 1));

		my $links_data = '';

		$cf->w_chunk_open(1);
		my $point_id = 0;
		foreach my $p (@{$self->{points}}) {
			$cf->w_chunk_open($point_id);
			$cf->w_chunk(0, pack('V', $point_id));
			my $data = pack('Z*f3VVv',
				$p->{name},
				@{$p->{position}},
				$p->{flags},
				$p->{level_vertex_id},
				$p->{game_vertex_id});
			$cf->w_chunk(1, $data);
			$cf->w_chunk_close();

			if ($#{$p->{links}} != -1) {
				$links_data .= pack('VV', $point_id, $#{$p->{links}} + 1);
				foreach my $l (@{$p->{links}}) {
					$links_data .= pack('Vf', $l->{to}, $l->{weight});
				}
			}
			$point_id++;
		}
		$cf->w_chunk_close();

		$cf->w_chunk(2, $links_data);
	$cf->w_chunk_close();
}
sub importing {
	my $self = shift;
	my ($if, $section) = @_;

	$self->{name} = $section;

	my $points = $if->value($section, 'points');
	fail('no points in path '.$section) unless defined $points;
	my %index_by_id;
	my $i = 0;
	foreach my $id (split /,/, $points) {
		$id =~ s/^\s*|\s*$//g;

		my %point;
		$point{name} = $if->value($section, "$id:name");
		my $flags = $if->value($section, "$id:flags");
		if (!defined $flags) {
			$flags = 0;
		} elsif ($flags =~ /^\s*0[xX]/) {
			$flags = hex $flags;
		}
		$point{flags} = $flags;
		my $position = $if->value($section, "$id:position");
		@{$point{position}} = split /,/, $position;
		$point{game_vertex_id} = $if->value($section, "$id:game_vertex_id");
		$point{level_vertex_id} = $if->value($section, "$id:level_vertex_id");
		$point{links0} = $if->value($section, "$id:links");

		push @{$self->{points}}, \%point;

		$index_by_id{$id} = $i++;
	}
	foreach my $p (@{$self->{points}}) {
		next unless defined $p->{links0};
		foreach my $l (split /,/, $p->{links0}) {
			$l =~ /^\s*(\w+)\s*\((\S+)\)\s*$/;
			die unless defined $1;
			die unless defined $2;
			my %link;
			$link{to} = $index_by_id{$1};
			$link{weight} = $2;
			push @{$p->{links}}, \%link;
		}
		delete $p->{links0};
	}
}
sub export {
	my $self = shift;
	my ($if, $id) = @_;
	my $fh = $if->{fh};

	print $fh "[$self->{name}]\n";
	my @points;
	my $i = 0;
	foreach my $p (@{$self->{points}}) {
		push @points, "p$i";
		$i++;
	}
	print $fh "points = ", join(',', @points), "\n";
	$i = 0;
	foreach my $p (@{$self->{points}}) {
		my $id = "p$i";
		print $fh "$id:name = $p->{name}\n";
		printf ($fh "$id:flags = %#x\n", $p->{flags}) unless $p->{flags} == 0;
		print $fh "$id:position = ", join(',', @{$p->{position}}), "\n";
		print $fh "$id:game_vertex_id = $p->{game_vertex_id}\n";
		printf $fh "$id:level_vertex_id = %d\n", $p->{level_vertex_id};
		if ($#{$p->{links}} != -1) {
			my @links;
			my $j = 0;
			foreach my $l (@{$p->{links}}) {
				push @links, "p$l->{to}($l->{weight})";
				$j++;
			}
			print $fh "$id:links = ", join(',', @links), "\n"; ;
		}
		$i++;
		print $fh "\n";
	}
	print $fh "\n";
}
sub split_ways {
	my $self = shift;
	my ($cf, $object_id) = @_;
	$cf->w_chunk_open($object_id);
	$cf->w_chunk_open(1);
	$cf->w_chunk_data(pack('v', 0x13));
	$cf->w_chunk_close();
	
	$cf->w_chunk_open(5);
	$cf->w_chunk_data(pack('Z*', $self->{name}));
	$cf->w_chunk_close();

	$cf->w_chunk_open(2);
	$cf->w_chunk_data(pack('v', $#{$self->{points}} + 1));
	my $links_data = '';
	my $point_id = 0;
	foreach my $p (@{$self->{points}}) {
		my $data = pack('f3VZ*',
		@{$p->{position}},
		$p->{flags},
		$p->{name});
		$cf->w_chunk_data($data);
	}
	$cf->w_chunk_close();
	$cf->w_chunk_open(3);
	my $id = 0;
	foreach my $p (@{$self->{points}}) {
		if ($#{$p->{links}} != -1) {
			foreach my $l (@{$p->{links}}) {
				$links_data .= pack('vvf', $point_id, $l->{to}, $l->{weight});
				$id++;
			}
		}
		$point_id++;
	}
	$cf->w_chunk_data(pack('v', $id));
	$cf->w_chunk_data($links_data);
	$cf->w_chunk_close();
	$cf->w_chunk_close();
}
1;
#######################################################################