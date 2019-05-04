# Module for handle RIFF-files
# Update history: 
#	26/08/2012 - fix for new fail() syntax
######################################################
package stkutils::chunked;
use strict;
use stkutils::debug qw(fail);
use IO::File;
sub new {
	my $class = shift;
	my $self = {};
	my $fh;
	${$self->{input_data}} = '';
	$self->{mode} = $_[1];
	if ($self->{mode} eq 'r') {
		$fh = IO::File->new($_[0], $self->{mode}) or return undef;
		binmode $fh;
		my $data = '';
		$fh->read($data, ($fh->stat())[7]);
		$fh->close();
		$self->{input_data} = \$data;
	} elsif ($self->{mode} eq 'w') {
		$fh = IO::File->new($_[0], $self->{mode}) or return undef;
		binmode $fh;
		$self->{fh} = $fh;
	} elsif ($self->{mode} eq 'data') {
		$self->{input_data} = $_[0];
	} else {
		fail('wrong or missing mode');
	}
	$self->{output_data} = '';
	$self->{offset} = 0;
	$self->{glob_pos} = [];
	$self->{end_offsets} = [];
	$self->{start_offsets} = [];
	bless($self, $class);
	return $self;
}
sub close {
	my $self = shift;
	if ($self->{mode} eq 'w') {
		$self->{fh}->close();
		$self->{fh} = undef;
	} else {
		undef $self->{input_data};
#		undef $self->{output_data};
	}
}
sub r_chunk_open {
	my $self = shift;
	my $offset = $self->{end_offsets}[$#{$self->{end_offsets}}];
	defined($offset) && $self->{offset} >= $offset && return undef;
	return undef if length(${$self->{input_data}}) <= $self->{offset} + 8;
	my $data = substr(${$self->{input_data}}, $self->{offset}, 8);
	my ($index, $size) = unpack('VV', $data);
	$self->{offset} += 8;
	push @{$self->{start_offsets}}, $self->{offset};
	push @{$self->{end_offsets}}, ($self->{offset} + $size);
	return ($index, $size);
}
sub r_chunk_close {
	my $self = shift;
	my $offset = pop @{$self->{end_offsets}};
	$self->{offset} <= $offset or fail('current position ('.$self->{offset}.') is outside current chunk ('.$offset.')');
	if ($self->{offset} < $offset) {
		$self->{offset} = $offset;
	}
	pop @{$self->{start_offsets}};
}
sub find_chunk {
	my $self = shift;
	my ($chunk) = @_;
	my $gl_pos = $self->{offset};
	my $offset = $self->{end_offsets}[$#{$self->{end_offsets}}];
	if ($self->{mode} eq 'data' or $self->{mode} eq 'r') {
		defined ($offset) or $offset = length(${$self->{input_data}});
	} else {
		fail('cannot read data while in write-mode');
	}
	defined ($offset) && $self->{offset} >= $offset && return undef;
	my $data;
	while ($self->{offset} < $offset) {
		my ($index, $size) = $self->r_chunk_open();
		if ($index == 0 && $size == 0) {
			$self->r_chunk_close();
			pop @{$self->{end_offsets}};
			my $pos = $self->{offset};
			push @{$self->{end_offsets}}, $pos - 8;
			$offset = $self->{end_offsets}[$#{$self->{end_offsets}}];
			last;
		}
		if ($index == $chunk) {
			push @{$self->{glob_pos}}, $gl_pos;
			return $size;
		}
		$self->r_chunk_close();
	}
	$self->{offset} = $gl_pos;
	return undef;
}
sub close_found_chunk {
	my $self = shift;
	my $offset = pop @{$self->{end_offsets}};
	defined $offset or $offset = $self->{offset};
	$self->{offset} <= $offset or fail('current position is outside current chunk');
	$self->{offset} = pop @{$self->{glob_pos}};
	pop @{$self->{start_offsets}};
}
sub r_chunk_safe {
	my $self = shift;
	my ($id, $dsize) = @_;
	my $size = $self->find_chunk($id);
	if ($size && $size == $dsize) {
		return $size;
	} elsif ($size) {
		fail("size of chunk $id ($size) is not match with expected size ($dsize)");
	} else {
		return undef;
	}
}
sub r_chunk_data {
	my $self = shift;
	my ($size) = @_;
	my $offset = $self->{end_offsets}[$#{$self->{end_offsets}}];
	defined($size) or $size = $offset - $self->{offset};
	$self->{offset} + $size <= $offset or fail('length of requested data is bigger than one left in chunk');
	my $data = '';
	if ($size > 0) {
		$data = substr(${$self->{input_data}}, $self->{offset}, $size) or fail('cannot read requested data');
	}
	$self->{offset} += $size;
	return \$data;
}
sub seek {
	my $self = shift;
	my ($seek_offset) = @_;
	defined($seek_offset) or fail('you must set seek offset to use this method');
	my $base = $self->{start_offsets}[$#{$self->{start_offsets}}];
	if ($self->{mode} eq 'w') {
		$self->{fh}->seek($base + $seek_offset, SEEK_SET);
	}
	$self->{offset} = $base + $seek_offset;
}
sub w_chunk_open {
	my $self = shift;
	my ($index) = @_;
	my $data = pack('VV', $index, 0xaaaaaaaa);
	if ($self->{mode} eq 'data') {
		$self->{output_data} .= $data;
	} elsif ($self->{mode} eq 'w') {
		$self->{fh}->write($data, 8) or fail("cannot open chunk $index");
	} else {
		fail('cannot write data while in read-mode');
	}
	push @{$self->{start_offsets}}, $self->{offset};
	$self->{offset} += 8;
}
sub w_chunk_close {
	my $self = shift;
	my $offset = pop @{$self->{start_offsets}};
	my $data = pack('V', $self->{offset} - $offset - 8);
	if ($self->{mode} eq 'data') {
		substr($self->{output_data}, $offset + 4, 4, $data);
	} elsif ($self->{mode} eq 'w') {
		$self->{fh}->seek($offset + 4, SEEK_SET) or fail("cannot close chunk");
		$self->{fh}->write($data, 4) or fail("cannot write size of chunk");
		$self->{fh}->seek($self->{offset}, SEEK_SET) or fail("cannot seek current write position");
	} else {
		fail('cannot write data while in read-mode');
	}
}
sub w_chunk_data {
	my $self = shift;
	my ($data) = @_;
	my $size = length($data);
	if ($self->{mode} eq 'data') {
		$self->{output_data} .= $data;
	} elsif ($self->{mode} eq 'w') {
		$self->{fh}->write($data, $size) or fail("cannot write data");
	} else {
		fail('cannot write data while in read-mode');
	}
	$self->{offset} += $size;
}
sub w_chunk {
	my $self = shift;
	my ($index, $data) = @_;
	my $size = length($data);
	my $hdr = pack('VV', $index, $size);
	if ($self->{mode} eq 'data') {
		$self->{output_data} .= $hdr;
		$self->{output_data} .= $data;
	} elsif ($self->{mode} eq 'w') {
		$self->{fh}->write($hdr, 8) or fail("cannot write header of chunk $index");
		$size > 0 && ($self->{fh}->write($data, $size) or fail("cannot write data in chunk $index"));
	} else {
		fail('cannot write data while in read-mode');
	}
	$self->{offset} += $size + 8;
}
sub data {return \$_[0]->{output_data}}
sub offset {
	return $_[0]->{offset} if $#_ == 0;
	$_[0]->{offset} = $_[1];
}
1;
