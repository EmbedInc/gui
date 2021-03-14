@echo off
rem
rem   BUILD_LIB [-dbg]
rem
rem   Build the GUI library.
rem
setlocal
call build_pasinit

call src_insall %srcdir% %libname%

call src_pas %srcdir% %libname%_child %1
call src_pas %srcdir% %libname%_enter %1
call src_pas %srcdir% %libname%_estr %1
call src_pas %srcdir% %libname%_events %1
call src_pas %srcdir% %libname%_evhan %1
call src_pas %srcdir% %libname%_key %1
call src_pas %srcdir% %libname%_menu %1
call src_pas %srcdir% %libname%_menu_ent %1
call src_pas %srcdir% %libname%_message %1
call src_pas %srcdir% %libname%_mmsg %1
call src_pas %srcdir% %libname%_ticks_make %1
call src_pas %srcdir% %libname%_util %1
call src_pas %srcdir% %libname%_win %1

call src_lib %srcdir% %libname%
call src_msg %srcdir% %libname%
