#!/bin/bash
# Nested restart integration test namelist.
#
# Same configuration as Nested.sh (the nested example + run-control overrides),
# plus the restart settings: this run restarts from the checkpoint the Nested
# case wrote and continues to the same end time. See Standard.sh and
# helpers/example_namelists/set_nml_var.py for how set_var works.
out_file=$1
examples="$(cd "$(dirname "$0")/../../../../helpers/example_namelists" && pwd)"
set_var() { "${PYTHON:-python3}" "$examples/set_nml_var.py" "$out_file" "$1" "$2" --group "$3" --insert || exit 1; }

# Start from the nested example (nests / parent_nest / dx already set there)
cp "$examples/nested.nml" "$out_file"

# Run window (same as Nested so the checkpoint lines up)
set_var start_date "'2017-02-14 00:00:00','2017-02-14 01:00:00'" general
set_var end_date   "'2017-02-14 01:20:00'"                       general

set_var outputinterval  600 output
set_var restartinterval 1   restart

# Same I/O folders as Nested — restart reads Nested's checkpoint
set_var output_folder  "'../output/Nested/'"  output
set_var restart_folder "'../restart/Nested/'" restart

# Restart from the 01:10 checkpoint
set_var restart_date "'2017-02-14 01:10:00'" restart
set_var restart_run  .True.                   restart
