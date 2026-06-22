#!/bin/bash
# SNOWPACK C++ vs native-Fortran comparison namelist.
#
# Like the other generators, this starts from the committed alpine_realdata
# EXAMPLE namelist and overrides only what the SNOWPACK parity comparison needs
# (see tests/snowpack/test_snowpack_compare.sh). The two comparison runs use the
# SAME namelist; only the executable's snow driver differs.
#
# The run is a 3 h midday window (10:00-13:00 UTC) on the Gaudergrat domain that
# tests/snowpack/make_snowpack_init.py has seeded with a 14-layer / 1 m snowpack:
#   * the run window matches the +10 h time-shifted forcing AND the seeder's
#     default depositionDate (2017-02-14 10:00), so snow ages are consistent;
#   * the snow model is SNOWPACK (sm = 'snowpack');
#   * snowpack_reduce_n_elements = 0 keeps the prescribed 14-layer mesh (the
#     aggressive layer-reduction is not bit-aligned between the C++ and the
#     Fortran port, so it is disabled in BOTH to compare the physics, not the
#     mesh churn);
#   * the snowpack_*_var domain options name the seeded snow-state variables so
#     the C++ wrapper (sm_SNOWPACK.F90) reads the prescribed snowpack — the
#     Fortran port reads the same variables through the standard domain read.
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

# 3 h midday window (matches the +10 h shifted forcing and the seeder's
# default depositionDate of 2017-02-14 10:00)
set_var start_date "'2017-02-14 10:00:00'" general
set_var end_date   "'2017-02-14 13:00:00'" general

# Read the seeded snowpack instead of the bare Gaudergrat domain
set_var init_conditions_file "'../domains/Gaudergrat_250m_snowpack.nc'" domain

# Turn on the SNOWPACK snow model
set_var sm "'snowpack'" physics

# Keep the prescribed 14-layer mesh (disable aggressive layer reduction in both
# the C++ build and the Fortran port so the comparison is of the physics)
set_var snowpack_reduce_n_elements 0 sm_parameters

# Names of the seeded snow-state variables in the domain file (written by
# tests/snowpack/make_snowpack_init.py). The C++ wrapper reads the snow state
# through these namelist options; they default to '' (no read).
set_var snowpack_nlayers_var     "'snowpack_nlayers'"   domain
set_var snowpack_deposition_var  "'depositionDate'"     domain
set_var snowpack_vfi_var         "'Vol_Frac_I'"         domain
set_var snowpack_vfw_var         "'Vol_Frac_W'"         domain
set_var snowpack_vfa_var         "'Vol_Frac_A'"         domain
set_var snowpack_vfs_var         "'Vol_Frac_S'"         domain
set_var snowpack_vfwp_var        "'Vol_Frac_WP'"        domain
set_var snowpack_ds_var          "'Ds'"                 domain
set_var snowpack_tsnow_var       "'snow_temperature'"   domain
set_var snowpack_tsnow_i_var     "'snow_temperature_i'" domain
set_var snowpack_rg_var          "'Rg'"                 domain
set_var snowpack_rb_var          "'Rb'"                 domain
set_var snowpack_dd_var          "'Dd'"                 domain
set_var snowpack_sp_var          "'Sp'"                 domain
set_var snowpack_mk_var          "'mk'"                 domain
set_var snowpack_cdot_var        "'CDot'"               domain
set_var snowpack_snow_stress_var "'snow_stress'"        domain

# Per-case I/O folders. test_snowpack_compare.sh seds these Standard paths to
# per-build SNOWPACK_<label> folders, so the two runs don't collide.
set_var output_folder  "'../output/Standard/'"  output
set_var restart_folder "'../restart/Standard/'" restart
