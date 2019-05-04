# Module for handling level.cform stalker files
# Update history:
#	27/08/2012 - fix code for new fail() syntax
##################################################
=comment
This is readme for level_cform.pm module. Using this module you can decompile and compile cform of s.t.a.l.k.e.r maps (build 1893 and later)
How it works.
1. new - create object of cform data:

my $cform = stkutils::level_cform->new($some_handle);

There are two kinds of argument:
	-filename. For newer builds (1580 and newer, xrlc_version >= 12) where level.cform exists.
	-reference (it's important!) to cform chunk data. For older builds (before 1580, xrlc_version < 12) where cform is one of level chunks.

2. decompile - unpacks data string into hashes and scalars, containing handable data. Takes no arguments.
structure of object after decompiling:
	$cform->{version} - scalar, version of xrlc
	$cform->{vertcount} - scalar, number of vertices
	$cform->{facecount} - scalar, number of faces
	@{$cform->{vertices}} - array, number of vertices. Each vertex contain only one reference to array @{$vertex->{coords}}, which is array of three coordinates of vertex.
	@{$cform->{faces}} - array, number of faces. Each face has a references to scalar $face->{material} and array @{$face->{coords}} with three vertices of which face consists.

3. compile - packs data into one string data and puts ref to this data in $cform->{data}. Method is complete opposite to compile. Takes no arguments.
4. write - writes cform chunk, using filehandle as argument.
5. export - exports data in external file. Takes an argument:
	- 'bin' - exports undecompiled binary data into FSL_CFORM.bin
	- other or no arguments at all - exports decompiled data into text file FSL_CFORM.ltx.
6. import - imports data from file. Same arguments as for 'export'.

Copyrights:
recovering cform format for final games - bardak.
recovering cform format for builds and perl implementing - K.D.
Last modified: 01.10.2011 5:29

Have fun!
=cut
package stkutils::level::level_cform;
use strict;
use IO::File;
use stkutils::data_packet;
use stkutils::ini_file;
use stkutils::debug qw(fail);
sub new {
	my $class = shift;
	my $self = {};
	$self->{bbox} = {};
	$self->{data} = '';
	$self->{data} = $_[0] if defined $_[0];
	bless($self, $class);
	return $self;
}
sub DESTROY {
	my $self = shift;
	foreach my $coord (@{$self->{vertices}}) {
		$coord->[0] = undef;
		$coord->[1] = undef;
		$coord->[2] = undef;
		@$coord = ();
	}
	foreach my $face (@{$self->{faces}}) {
		$face->{vertices}[0] = undef;
		$face->{vertices}[1] = undef;	
		$face->{vertices}[2] = undef;	
		$face->{material} = undef;
		%$face = ();
	}
	@{$self->{faces}} = ();
	@{$self->{vertices}} = ();
}
sub decompile {
	my $self = shift;
	my $mode = shift;
	my $packet = stkutils::data_packet->new($self->{data});
	($self->{version}, $self->{vertcount}, $self->{facecount}) = $packet->unpack('VVV', 12);
	@{$self->{bbox}->{min}} = $packet->unpack('f3', 12);
	@{$self->{bbox}->{max}} = $packet->unpack('f3', 12);
	if ($mode && ($mode eq 'full')) {
		for (my $i = 0; $i < $self->{vertcount}; $i++) {
			my @coords = $packet->unpack('f3', 12);
			push @{$self->{vertices}}, \@coords;
		}
		for (my $i = 0; $i < $self->{facecount}; $i++) {
			my $face = {};
			@{$face->{vertices}} = $packet->unpack('V3', 12);
			($face->{material}) = $packet->unpack('V', 4);
			#material field is a material index on gamemtl.xr (xrlc ver.12 (build 1580-2218))
			#in newer builds (and all final games) it consist of additional data:
			#	-1-14th bits is a material index
			#	-15th bit is suppress shadows flag (on/off)
			#	-16th bit is suppress wallmarks flag (on/off)
			#	-17-32th bits is a sector (dunno what's this, it's from bardak's dumper) 
			push @{$self->{faces}}, $face;
		}
	}
#	sleep(10);	#87432
}
sub compile {
	my $self = shift;
	
	my $packet = stkutils::data_packet->new();
	$packet->pack('VVVf3f3', $self->{version}, $self->{vertcount}, $self->{facecount}, @{$self->{bbox}->{min}}, @{$self->{bbox}->{max}});
	foreach my $coord (@{$self->{vertices}}) {
		$packet->pack('f3', @$coord);
	}
	foreach my $face (@{$self->{faces}}) {
		$packet->pack('V3V', @{$face->{vertices}}, $face->{material});
	}
	$self->{data} = \$packet->data();
}
sub write {
	my $self = shift;
	my ($fh) = @_;
	if ($self->{version} < 2) {
		$fh->w_chunk(0x6, ${$self->{data}});	
	} elsif ($self->{version} < 4) {
		$fh->w_chunk(0x5, ${$self->{data}});	
	} else {
		$fh->write(${$self->{data}}, length(${$self->{data}}));
	}
}
sub export_ltx {
	my $self = shift;
	my ($fh) = @_;
	
	print $fh "[header]\n";
	print $fh "version = $self->{version}\n";
	print $fh "vert_count = $self->{vertcount}\n";
	print $fh "face_count = $self->{facecount}\n";
	printf $fh "bbox_min = %f, %f, %f\n", @{$self->{bbox}->{min}};
	printf $fh "bbox_max = %f, %f, %f\n", @{$self->{bbox}->{max}};
	print $fh "\n[vertices]\n";
	my $i = 0;
	foreach my $vertex (@{$self->{vertices}}) {
		printf $fh "vertex_$i = %f, %f, %f\n", @{$vertex->{coords}};
		$i++;
	}
	my $j = 0;
	foreach my $face (@{$self->{faces}}) {
		print $fh "\n[face_$j]\n";
		printf $fh "vertices = %f, %f, %f\n", @{$face->{coords}};
		print $fh "material = $self->{material}\n";
		$j++;
	}
}
sub import_ltx {
	my $self = shift;
	my ($fh) = @_;
	
	$self->{version} = $fh->value('header', 'version');
	$self->{vertcount} = $fh->value('header', 'vert_count');
	$self->{facecount} = $fh->value('header', 'face_count');
	@{$self->{bbox}->{min}} = split /,\s*/, $fh->value('header', 'bbox_min');
	@{$self->{bbox}->{max}} = split /,\s*/, $fh->value('header', 'bbox_max');	
	for (my $i = 0; $i < $self->{vertcount}; $i++) {
		my $vertex = {};
		@{$vertex->{coords}} = split /,\s*/, $fh->value('vertices', "vertex_$i");	
		push @{$self->{vertices}}, $vertex;
	}
	for (my $i = 0; $i < $self->{facecount}; $i++) {
		my $face = {};
		@{$face->{coords}} = split /,\s*/, $fh->value("face_$i", 'vertices');	
		$self->{material} = $fh->value("face_$i", 'material');
		push @{$self->{faces}}, $face;
	}
}
sub calculate_bbox {
	my $bbox = $_[0]->{bbox};
	my @vertices = @{$_[0]->{vertices}};
	$bbox->{min}[0] = $vertices[0]->[0];
	$bbox->{min}[1] = $vertices[0]->[1];
	$bbox->{min}[2] = $vertices[0]->[2];
	$bbox->{max}[0] = $vertices[0]->[0];
	$bbox->{max}[1] = $vertices[0]->[1];
	$bbox->{max}[2] = $vertices[0]->[2];
	foreach (@vertices) {
		$bbox->{min}[0] = $$_[0] if $bbox->{min}[0] > $$_[0];
		$bbox->{min}[1] = $$_[1] if $bbox->{min}[1] > $$_[1];
		$bbox->{min}[2] = $$_[2] if $bbox->{min}[2] > $$_[2];
		$bbox->{max}[0] = $$_[0] if $bbox->{max}[0] < $$_[0];
		$bbox->{max}[1] = $$_[1] if $bbox->{max}[1] < $$_[1];
		$bbox->{max}[2] = $$_[2] if $bbox->{max}[2] < $$_[2];
	}
}
1;
#######################################################################