#!/bin/bash
# Nested integration test namelist.
#
# Starts from the committed nested EXAMPLE namelist (two domains) and overrides
# only the run-control settings the test harness needs. See Standard.sh and
# helpers/example_namelists/set_nml_var.py for how set_var works.
out_file=$1
examples="$(cd "$(dirname "$0")/../../../../helpers/example_namelists" && pwd)"
set_var() { "${PYTHON:-python3}" "$examples/set_nml_var.py" "$out_file" "$1" "$2" --group "$3" --insert || exit 1; }

# Start from the nested example (nests / parent_nest / dx already set there)
cp "$examples/nested.nml" "$out_file"

# Run window for the Nested test: child nest starts one hour into the parent run
set_var start_date "'2017-02-14 00:00:00','2017-02-14 01:00:00'" general
set_var end_date   "'2017-02-14 01:20:00'"                       general

set_var outputinterval  600 output
set_var restartinterval 1   restart

set_var output_folder  "'../output/Nested/'"  output
set_var restart_folder "'../restart/Nested/'" restart
