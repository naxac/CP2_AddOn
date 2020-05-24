@echo off

copy /Y acdc.pl spawn_unpack\acdc.pl
xcopy /Y stkutils "spawn_unpack\stkutils\"
if exist all.spawn (
	ren all.spawn all.spawn.old
)
if exist all.spawn.new (
	del /Q all.spawn.new
)

pushd spawn_unpack\

perl acdc.pl -c all.ltx -o ..\all.spawn.new

del /Q acdc.pl
rd /S /Q stkutils

@pause