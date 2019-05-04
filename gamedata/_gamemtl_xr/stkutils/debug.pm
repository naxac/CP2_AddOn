# debug module for stalker perl scripts
# Update history:
#	26/08/2012 - new debug system, add switching output
##################################################
package stkutils::debug;

use strict;
use IO::Handle;
use IO::File;

use constant STDERR_CONSOLE => 0x1;
use constant STDOUT_CONSOLE => 0x2;
use constant STDERR_FILE => 0x4;
use constant STDOUT_FILE => 0x8;

use vars qw(@ISA @EXPORT_OK);
require Exporter;

@ISA		= qw(Exporter);
@EXPORT_OK	= qw(fail warn STDERR_CONSOLE STDOUT_CONSOLE STDERR_FILE STDOUT_FILE);

sub new {
	my $class = shift;
	my $self = {};
	$self->{mask} = $_[0];
	$self->{log} = '';
	print "log inited: ";
	if (($self->{mask} & STDERR_FILE) == STDERR_FILE || ($self->{mask} & STDOUT_FILE) == STDOUT_FILE) {
		fail("you cant print both file and console!") if (($self->{mask} & STDERR_FILE) == STDERR_FILE && ($self->{mask} & STDERR_CONSOLE) == STDERR_CONSOLE);
		fail("you cant print both file and console!") if (($self->{mask} & STDOUT_FILE) == STDOUT_FILE && ($self->{mask} & STDOUT_CONSOLE) == STDOUT_CONSOLE);
		print "$_[1]\n";
		my $log = IO::File->new($_[1], 'w');
		STDERR->fdopen(\*$log, 'w') if ($self->{mask} & STDERR_FILE) == STDERR_FILE;
		STDOUT->fdopen(\*$log, 'w') if ($self->{mask} & STDOUT_FILE) == STDOUT_FILE;
		$self->{log} = $log;
	} else {
		print "console\n";
	}
	bless $self, $class;
	return $self;
}

sub DESTROY {
	my $self = shift;
	if (($self->{mask} & STDERR_FILE) == STDERR_FILE || ($self->{mask} & STDOUT_FILE) == STDOUT_FILE) {
		STDERR->close() if ($self->{mask} & STDERR_FILE) == STDERR_FILE;
		STDOUT->close() if ($self->{mask} & STDOUT_FILE) == STDOUT_FILE;
		$self->{log}->close();
		$self->{log} = undef;
	}
}
sub fail {
	my @first_frame = caller(0);
	my @second_frame = caller(1);	
	my $func = $second_frame[3];
	$func = $first_frame[0] unless defined $func;
	my $line = $first_frame[2];
	die "\nFATAL ERROR!\nFunction: $func\nLine: $line\nDescription: @_\n";
}
sub warn {
	my @first_frame = caller(0);
	my @second_frame = caller(1);	
	my $func = $second_frame[3];
	$func = $first_frame[0] unless defined $func;
	my $line = $first_frame[2];
	warn "\nWARNING!\nFunction: $func\nLine: $line\nDescription: @_\n";
}
######################################################################
1;