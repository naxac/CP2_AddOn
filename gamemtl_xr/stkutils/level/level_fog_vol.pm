# Module for handling level.fog_vol stalker files
# Update history:
#	27/08/2012 - fix code for new fail() syntax
#	05/08/2012 - initial release
##################################################
package stkutils::level::level_fog_vol;
use strict;
use stkutils::debug qw(fail);
use stkutils::data_packet;
sub new {
	my $class = shift;
	my $self = {};
	$self->{data} = '';
	$self->{data} = $_[0] if $#_ == 0;
	bless $self, $class;
	return $self;
}
sub read {
	my $self = shift;
	my $packet = stkutils::data_packet->new($self->{data});
	($self->{version}, $self->{num_volumes}) = $packet->unpack('vV', 6);
	fail('unsupported version '.$self->{version}) unless ($self->{version} == 2 || $self->{version} == 3);
	for (my $i = 0; $i < $self->{num_volumes}; $i++) {
		my $volume = {};
		for (;;) {
			my $char = $packet->raw(1);
			last if ($char eq "\n" || $char eq "\r");			
			$volume->{ltx} .= $char;
		}
		my $char = $packet->raw(1);
		fail('unexpected string format') unless $char eq "\n";
		@{$volume->{xform}} = $packet->unpack('f16', 64);
#		print "\n@{$volume->{xform}}[0..3]\n@{$volume->{xform}}[4..7]\n@{$volume->{xform}}[8..11]\n@{$volume->{xform}}[12..15]\n";
		my ($particle_count) = $packet->unpack('V', 4);
		for (my $j = 0; $j < $particle_count; $j++) {
			my @particle = $packet->unpack('f16', 64);
#			print "\n	@particle[0..3]\n	@particle[4..7]\n	@particle[8..11]\n	@particle[12..15]\n";
			push @{$volume->{particles}}, \@particle;
		}
		push @{$self->{volumes}}, $volume;
	}
}
sub write {
	my $self = shift;
	my $packet = stkutils::data_packet->new();
	$packet->pack('vV', $self->{version}, $self->{num_volumes});
	foreach my $volume (@{$self->{volumes}}) {	
		$volume->{ltx} .= "\r\n";
		$packet->pack('A*f16V', $volume->{ltx}, @{$volume->{xform}}, $#{$volume->{particles}} + 1);
		foreach my $particle (@{$volume->{particles}}) {
			$packet->pack('f16', @$particle);
		}
	}
	$self->{data} = \$packet->data();
}
1;
###########################################