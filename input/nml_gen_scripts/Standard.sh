#!/bin/bash
# Standard integration test namelist.
#
# This starts from the committed alpine_realdata EXAMPLE namelist and overrides
# only the run-control settings the test harness needs (run window, output
# cadence, per-case I/O folders). Building the test on top of the example means
# the full-test suite also verifies that the example namelist actually runs.
#
# Each line is `set_var <name> <value> <group>`, which rewrites that variable by
# name (independent of the model defaults) and INSERTS it into &<group> if the
# example left it at its default (so it was stripped out). See
# helpers/example_namelists/set_nml_var.py.
out_file=$1
examples="$(cd "$(dirname "$0")/../../../../helpers/example_namelists" && pwd)"
set_var() { "${PYTHON:-python3}" "$examples/set_nml_var.py" "$out_file" "$1" "$2" --group "$3" --insert || exit 1; }

# Start from the alpine_realdata example
cp "$examples/alpine_realdata.nml" "$out_file"

# Run window for the Standard test (matches the historical Standard case)
set_var start_date "'2017-02-14 00:00:00'" general
set_var end_date   "'2017-02-14 00:20:00'" general

# Output every 10 min; write a restart checkpoint at every output
set_var outputinterval  600 output
set_var restartinterval 1   restart

# Per-case I/O folders so cases don't collide and the harness finds the output
set_var output_folder  "'../output/Standard/'"  output
set_var restart_folder "'../restart/Standard/'" restart
