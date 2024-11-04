#!/bin/bash -f
echo Simulation Tool: Viavdo Simulator
if test $1 = "ARTYA7"; then
echo arty35t
xelab work.m_main work.glbl -prj xsim_files-arty35t.prj -L unisims_ver -L secureip -s xsim_test -debug typical
else
echo nexys4
xelab work.m_main work.glbl -prj xsim_files-nexys4.prj -L unisims_ver -L secureip -s xsim_test -debug typical
fi
if test $? -eq 0; then
xsim -g -t xsim_options.tcl -wdb xsim_database.wdb xsim_test
fi
echo done

