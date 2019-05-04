# Module providing some useful methods
# Update history: 
#	27/08/2012 - fix read_file() and write_file() for binmode
#	26/08/2012 - fix for new fail() syntax, merging with filehandler.pm, add get_includes()
#############################################
package stkutils::utils;
use strict;
use stkutils::debug qw(fail);
use IO::File;
use vars qw(@ISA @EXPORT_OK);
require Exporter;

@ISA		= qw(Exporter);
@EXPORT_OK	= qw(get_filelist get_includes read_file write_file get_path get_all_includes);

sub read_file {
	my $fh = IO::File->new($_[0], 'r') or fail("$!: $_[0]\n");
	binmode $fh;
	my $data = '';
	$fh->read($data, ($fh->stat())[7]);
	$fh->close();
	return \$data;
}
sub write_file {
	my $fh = IO::File->new($_[0], 'w') or fail("$!: $_[0]\n");
	binmode $fh;
	$fh->write(${$_[1]}, length(${$_[1]}));
	$fh->close();
}
sub get_filelist {
# $_[0] - folder, $_[1] - file extensions 
	my @ext_list = _prepare_extensions_list($_[1]);
	my @files;
	if ($_[0] eq '')
	{
		@files = glob ("*");
	} else {
		if (!(-d $_[0])) {fail("not a folder\n")};
		@files = glob ("$_[0]/*");
	}
	my @out;
	foreach (@files) {
		if (-d $_) {
			my $temp = get_filelist("$_", $_[1]);
			push @out, @$temp;
		} elsif (-f $_ and _has_desired_extension($_, \@ext_list)) {
			push @out, $_;
		}
	}
	return \@out;
}
sub _prepare_extensions_list {return split /,/, $_[0];}
sub _has_desired_extension {
	return 1 if ($#{$_[1]} == -1);
	foreach my $ext (@{$_[1]}) {
		if (($_[0] =~ /$ext$/) || ($ext eq '')) {
			return 1;
		}
	}	
	return 0;
}
sub get_all_includes {
	my @out;
	my $base = $_[1];
	$base = $_[0].'\\'.$base if $_[0] ne '';
	my $list = get_includes($base);
	foreach my $f (@$list) {
		next if $f =~ /^mp\/|^mp\\/;
		my ($path, $file) = get_path($f);
#		print "$_[0]\\$path\\$file\n";
		my $in_l = get_all_includes($_[0].'\\'.$path, $file);
		foreach my $l (@$in_l) {
			$l = $path.'\\'.$l;
#			print "$l\n";
		}
		push @out, @$in_l;
	}
	push @out, @$list;
	return \@out;
}
sub get_includes {
	my $file = IO::File->new($_[0], 'r') or return undef;
	my @inc;
	while (<$file>) {
		if (/^(?<!;)#include "(.*)"/) {
			push @inc, $1;
		}
	}
	$file->close();
	return \@inc;
}
sub get_path {
	my @temp = split /\\/, $_[0];
	my $temp = pop @temp;
	return join('/', @temp), $temp;
}
##############################
1;
