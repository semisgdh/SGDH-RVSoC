#!/bin/bash -f
# ****************************************************************************
# Vivado (TM) v2022.1.2 (64-bit)
#
# Filename    : simulate.sh
# Simulator   : Xilinx Vivado Simulator
# Description : Script for simulating the design by launching the simulator
#
# Generated by Vivado on Sat Oct 19 18:32:15 KST 2024
# SW Build 3605665 on Fri Aug  5 22:52:02 MDT 2022
#
# IP Build 3603185 on Sat Aug  6 04:07:44 MDT 2022
#
# usage: simulate.sh
#
# ****************************************************************************
set -Eeuo pipefail
# simulate design
echo "xsim m_main_behav -key {Behavioral:sim_1:Functional:m_main} -tclbatch m_main.tcl -protoinst "protoinst_files/design_1.protoinst" -log simulate.log"
xsim m_main_behav -key {Behavioral:sim_1:Functional:m_main} -tclbatch m_main.tcl -protoinst "protoinst_files/design_1.protoinst" -log simulate.log
