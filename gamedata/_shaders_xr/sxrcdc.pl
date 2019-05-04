# S.T.A.L.K.E.R. shaders.xr compiler/decompiler
# Update history:
# 	v.0.2: 01/09/2012 - complete code refactoring
##############################################
use strict;
use Getopt::Long;
use stkutils::chunked;
use stkutils::debug qw(fail warn STDERR_CONSOLE STDOUT_CONSOLE STDERR_FILE STDOUT_FILE);
use stkutils::xr::shaders_xr;

# handle signals
$SIG{__WARN__} = sub{fail(@_);};

# parsing command line
my ($src, $out, $mode, $hmode, $log);
GetOptions(
	# main options
	'decompile:s' => \&process,
	'compile:s' => \&process,
	# common options
	'out=s' => \$out,
	'mode=s' => \$hmode,	
	'log:s' => \$log,
) or die usage();

# initializing debug
my $debug_mode = STDERR_CONSOLE|STDOUT_CONSOLE;
$debug_mode = STDERR_FILE|STDOUT_FILE if defined $log;
$log = 'sxrcdc.log' if defined $log && ($log eq '');
$hmode = 'bin' unless (defined $hmode and ($hmode ne ''));
my $debug = stkutils::debug->new($debug_mode, $log);

# start processing
SWITCH: {
	($mode eq 'decompile') && do {decompile(); last SWITCH;};
	($mode eq 'compile') && do {compile(); last SWITCH;};
}

print "done!\n";
$debug->DESTROY();

sub usage {
	print "shaders.xr compiler/decompiler\n";
	print "Usage:\n";
	print "decompile:	sxrcdc.pl -d <filename> [-out <path> -mode <ltx|bin> -log <log_filename>]\n";
	print "compile:	sxrcdc.pl -c <path> [-out <filename> -mode <ltx|bin> -log <log_filename>]\n";
}
sub process {
	$mode = $_[0];
	$src = $_[1];
}
sub decompile {
	$src = 'shaders.xr' if $src eq '';
	
	print "opening $src\n";
	my $fh = stkutils::chunked->new($src, 'r') or fail("$!: $src\n");
	my $pxr = stkutils::xr::shaders_xr->new();
	$pxr->read($fh, $hmode);
	$pxr->export($out, $hmode);
	$fh->close();
}
sub compile {
	$out = 'shaders.xr.new' if (!defined $out or ($out eq ''));
	
	print "opening $src\n";
	my $fh = stkutils::chunked->new($out, 'w') or fail("$!: $out\n");
	my $pxr = stkutils::xr::shaders_xr->new();
	$pxr->my_import($src, $hmode);
	$pxr->write($fh, $hmode);
	$fh->close();
}