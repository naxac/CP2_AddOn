# S.T.A.L.K.E.R. lanims.xr handling module
# Update history: 
#	29/08/2012 - initial release
##############################################
package stkutils::xr::lanims_xr;
use strict;
use stkutils::debug qw(fail);
use stkutils::data_packet;
use stkutils::ini_file;
use stkutils::utils qw(get_filelist get_path);
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
		SWITCH: {
			$index == 0 && do {$self->{version} = unpack('v', ${$fh->r_chunk_data()}); last SWITCH;};
			$index == 1 && do {$self->read_laitem($fh); last SWITCH;};
		}
		$fh->r_chunk_close();
	}
	$fh->close() if $#_ == -1;
}
sub read_laitem {
	my $self = shift;
	my ($fh) = @_;
	
	while (1) {
		my ($index, $size) = $fh->r_chunk_open();
		defined($index) or last;
		my $laitem = {};
		while (1) {
			my ($in_index, $in_size) = $fh->r_chunk_open();
			defined($in_index) or last;
			SWITCH: {
				$in_index == 1 && do {($laitem->{name}, $laitem->{fps}, $laitem->{frame_count}) = unpack('Z*fV', ${$fh->r_chunk_data()}); last SWITCH;};
				$in_index == 2 && do {
					my $packet = stkutils::data_packet->new($fh->r_chunk_data());
					my ($count) = $packet->unpack('V', 4);
					for (my $i = 0; $i < $count; $i++) {
						my $key = {};
						($key->{frame}, $key->{color}) = $packet->unpack('VV', 8);
						push @{$laitem->{keys}}, $key;
					}; 
					last SWITCH;};
			}
			$fh->r_chunk_close();
		}
		$fh->r_chunk_close();
		push @{$self->{laitems}}, $laitem;
	}	
}
sub write {
	my $self = shift;
	my ($fh) = @_;
	
	$fh = stkutils::chunked->new('', 'data') if $#_ == -1;
	my $i = 0;
	my $packet = stkutils::data_packet->new();
	$fh->w_chunk(0, pack('v', 1));		#version
	$fh->w_chunk_open(1);
	foreach my $obj (@{$self->{laitems}}) {
		$fh->w_chunk_open($i);
		
		$fh->w_chunk(1, pack('Z*fV', $obj->{name}, $obj->{fps}, $obj->{frame_count}));
		
		$fh->w_chunk_open(2);
		$fh->w_chunk_data(pack('V', $#{$obj->{keys}} + 1));
		foreach my $key (@{$obj->{keys}}) {
			$fh->w_chunk_data(pack('VV', $key->{frame}, $key->{color}));
		}
		$fh->w_chunk_close();
		
		$fh->w_chunk_close();
		$i++;
	}
	$fh->w_chunk_close();
	$self->{data} = $fh->data();
	$fh->close() if $#_ == -1;
}
sub export {
	my $self = shift;
	my ($out, $mode) = @_;
	
	mkpath($out);
	chdir $out or fail ("$out: $!\n");
	foreach my $laitem (@{$self->{laitems}}) {
		my $str = $laitem->{name}.'.ltx';
		my ($path, $fn) = get_path($str);
		mkpath($path) if defined $path && ($path ne '');
		my $ini = IO::File->new($str, 'w') or fail("$str: $!\n");
		print $ini "[header]\n";
		print $ini "name = $laitem->{name}\n";
		print $ini "fps = $laitem->{fps}\n";
		print $ini "frame_count = $laitem->{frame_count}\n\n";
		print $ini "[keys]\n";
		print $ini "keys_count = ".($#{$laitem->{keys}} + 1)."\n\n";
		my $i = 0;
		foreach my $key (@{$laitem->{keys}}) {
			print $ini "$i:frame = $key->{frame}\n";
			print $ini "$i:color = ";
			if ($mode && $mode == 1) {
				my $A = ($key->{color} >> 24) & 0xFF;
				my $R = ($key->{color} >> 16) & 0xFF;
				my $G = ($key->{color} >> 8) & 0xFF;
				my $B = $key->{color} & 0xFF;
				printf $ini "%u:%u:%u:%u\n\n", $A, $R, $G, $B;
			} else {
				print $ini "$key->{color}\n\n";
			}
			$i++;
		}
		$ini->close();
	}
}
sub my_import {
	my $self = shift;
	my ($src) = @_;

	my $list = get_filelist($src, 'ltx');
	foreach my $file (@$list) {
		my $ini = stkutils::ini_file->new($file, 'r') or fail("$file: $!\n");
		my $obj = {};
		$obj->{fps} = $ini->value('header', 'fps');
		$obj->{name} = $ini->value('header', 'name');
		$obj->{frame_count} = $ini->value('header', 'frame_count');
		my $count = $ini->value('keys', 'keys_count');
		for (my $i = 0; $i < $count; $i++) {
			my $key = {};
			$key->{frame} = $ini->value('keys', "$i:frame");
			$key->{color} = $ini->value('keys', "$i:color");
			if ($key->{color} =~ /:/) {
				my @temp = split /:/, $key->{color};
				$key->{color} = ($temp[0] << 24) + ($temp[1] << 16) + ($temp[2] << 8) + $temp[3];
			}
			push @{$obj->{keys}}, $key;
		}
		push @{$self->{laitems}}, $obj;
		$ini->close();
	}
}
#################################################################################
1;