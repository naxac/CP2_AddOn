# Module for handling level.geom/geomx stalker files
##################################################
package stkutils::level::level_geom;
use strict;
use base 'stkutils::level::level';
sub new {
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}
sub init_data_fields {
	my $self = shift;
	$self->{fsl_header} = fsl_header->new();
	$self->{fsl_header}->{xrlc_version} = $_[0];
	$self->{fsl_vertex_buffer} = fsl_vertex_buffer->new($_[0]);
	$self->{fsl_index_buffer} = fsl_index_buffer->new($_[0]);
	$self->{fsl_swis} = fsl_swis->new($_[0]);
}
sub prepare {
	my $self = shift;
	my ($level) = @_;
	$self->{fsl_header} = $level->{fsl_header};
	$self->{fsl_vertex_buffer} = $level->{fsl_vertex_buffer};
	$self->{fsl_index_buffer} = $level->{fsl_index_buffer};
	$self->{fsl_swis} = $level->{fsl_swis};
}
sub copy {
	my $self = shift;
	my ($copy) = @_;
	$copy->{fsl_vertex_buffer} = $self->{fsl_vertex_buffer};
	$copy->{fsl_index_buffer} = $self->{fsl_index_buffer};
	$copy->{fsl_swis} = $self->{fsl_swis};	
}	
sub write {
	my $self = shift;
	my ($fn) = @_;
	my $fh = stkutils::chunked->new($fn, 'w');
	$self->{fsl_header}->write($fh);
	$self->{fsl_vertex_buffer}->write($fh);	
	$self->{fsl_index_buffer}->write($fh);
	$self->{fsl_swis}->write($fh);
	$fh->close();	
}
sub importing {
	my $self = shift;
	$self->{fsl_header} = fsl_header->new();	
	$self->{fsl_header}->import_ltx();
	$self->_init_data_fields($self->get_version());
	import_data($self->{fsl_vertex_buffer});
	import_data($self->{fsl_swis});
	import_data($self->{fsl_index_buffer});
}
sub export {
	my $self = shift;
	export_data($self->{fsl_header}, 'ltx');
	export_data($self->{fsl_vertex_buffer});
	export_data($self->{fsl_swis});
	export_data($self->{fsl_index_buffer});
}
1;
##############################################