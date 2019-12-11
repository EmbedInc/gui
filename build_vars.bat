@echo off
rem
rem   Define the variables for running builds from this source library.
rem
set srcdir=gui
set buildname=
call treename_var "(cog)source/gui" sourcedir
set libname=gui
set fwname=
call treename_var "(cog)src/%srcdir%/debug_%fwname%.bat" tnam
make_debug "%tnam%"
call "%tnam%"
