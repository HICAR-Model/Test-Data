#!/bin/bash
# Nested "complex" restart integration test namelist.
#
# Like Nested_restart.sh, but restarts the parent at 00:50 — BEFORE the child
# nest's 01:00 start time — to exercise restarting a nest chain while a child is
# not yet active. See Standard.sh and helpers/example_namelists/set_nml_var.py
# for how set_var works. (Not wired into CI; kept in sync for manual use.)
out_file=$1
examples="$(cd "$(dirname "$0")/../../../../helpers/example_namelists" && pwd)"
set_var() { "${PYTHON:-python3}" "$examples/set_nml_var.py" "$out_file" "$1" "$2" --group "$3" --insert || exit 1; }

# Start from the nested example (nests / parent_nest / dx already set there)
cp "$examples/nested.nml" "$out_file"

set_var start_date "'2017-02-14 00:00:00','2017-02-14 01:00:00'" general
set_var end_date   "'2017-02-14 01:20:00'"                       general

set_var outputinterval  600 output
set_var restartinterval 1   restart

set_var output_folder  "'../output/Nested/'"  output
set_var restart_folder "'../restart/Nested/'" restart

# Restart from a 00:50 checkpoint — before the child nest starts at 01:00
set_var restart_date "'2017-02-14 00:50:00'" restart
set_var restart_run  .True.                   restart
