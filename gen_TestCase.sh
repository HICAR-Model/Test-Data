#!/bin/bash

#Use like: 
#./gen_TestCase.sh "../../HICAR/run/default_hicar_options.nml" HICAR_TestCase.nml

default_file=$(readlink -f $1)
out_file=$(readlink -f $2)

# copy default
cp $default_file $out_file

#replace necesarry namelist options
sed -i'.bak' "s/start_date = ''/start_date = '2017-02-14 00:00:00'/g" $out_file
sed -i'.bak' "s/end_date = ''/end_date = '2017-02-14 00:05:00'/g" $out_file
sed -i'.bak' 's/dx = 0.0/dx = 250.0/g' $out_file
sed -i'.bak' 's/nz = 500/nz = 40/g' $out_file
sed -i'.bak' 's/ pbl = 0/ pbl = 1/g' $out_file
sed -i'.bak' 's/ lsm = 0/ lsm = 3/g' $out_file
sed -i'.bak' 's/ sfc = 0/ sfc = 1/g' $out_file
sed -i'.bak' 's/ water = 0/ water = 1/g' $out_file
sed -i'.bak' 's/ mp = 0/ mp = 3/g' $out_file
sed -i'.bak' 's/ rad = 0/ rad = 3/g' $out_file
sed -i'.bak' 's/ adv = 0/ adv = 1/g' $out_file
sed -i'.bak' 's/ wind = 0/ wind = 3/g' $out_file
sed -i'.bak' 's/radiation_downscaling = 0/radiation_downscaling = 1/g' $out_file
sed -i'.bak' 's/Sx = .False./Sx = .True./g' $out_file
sed -i'.bak' "s/output_vars = ''/output_vars = 'qs','snow_height','ns','qg','ng','temperature','albedo','qi','ni','snowfall','ice1_a','lat','swtb','swtd','hfls','hfss','lwtr','lon','pressure','u'/g" $out_file
sed -i'.bak' "s/output_file = ''/output_file = '..\/output\/TestCase\/hicar_out_'/g" $out_file
sed -i'.bak' 's/inputinterval = 3600/inputinterval = 7200/g' $out_file
sed -i'.bak' "s/LU_Categories = 'MODIFIED_IGBP_MODIS_NOAH'/LU_Categories = 'USGS'/g" $out_file
sed -i'.bak' "s/ time_var = ''/ time_var = 'time'/g" $out_file
sed -i'.bak' "s/ pvar = ''/ pvar = 'P'/g" $out_file
sed -i'.bak' "s/ tvar = ''/ tvar = 'T'/g" $out_file
sed -i'.bak' "s/ qvvar = ''/ qvvar = 'QV'/g" $out_file
sed -i'.bak' "s/ hgtvar = ''/ hgtvar = 'HSURF'/g" $out_file
sed -i'.bak' "s/ zvar = ''/ zvar = 'HFL'/g" $out_file
sed -i'.bak' "s/ latvar = ''/ latvar = 'lat_1'/g" $out_file
sed -i'.bak' "s/ lonvar = ''/ lonvar = 'lon_1'/g" $out_file
sed -i'.bak' "s/ uvar = ''/ uvar = 'U'/g" $out_file
sed -i'.bak' "s/ vvar = ''/ vvar = 'V'/g" $out_file
sed -i'.bak' "s/ lat_hi = ''/ lat_hi = 'lat'/g" $out_file
sed -i'.bak' "s/ lon_hi = ''/ lon_hi = 'lon'/g" $out_file
sed -i'.bak' "s/ hgt_hi = ''/ hgt_hi = 'topo'/g" $out_file
sed -i'.bak' "s/ landvar = ''/ landvar = 'landmask'/g" $out_file
sed -i'.bak' "s/ vegtype_var = ''/ vegtype_var = 'landuse'/g" $out_file
sed -i'.bak' "s/ hlm_var = ''/ hlm_var = 'hlm'/g" $out_file
sed -i'.bak' "s/ svf_var = ''/ svf_var = 'svf'/g" $out_file
sed -i'.bak' "s/ slope_var = ''/ slope_var = 'slope'/g" $out_file
sed -i'.bak' "s/ slope_angle_var = ''/ slope_angle_var = 'slope_rad'/g" $out_file
sed -i'.bak' "s/ aspect_angle_var = ''/ aspect_angle_var = 'aspect_rad'/g" $out_file
sed -i'.bak' 's/smooth_wind_distance = -9999/smooth_wind_distance = 500.0/g' $out_file
sed -i'.bak' "s/init_conditions_file = ''/init_conditions_file = '..\/domains\/Gaudergrat_250m.nc'/g" $out_file
sed -i'.bak' "s/forcing_file_list = ''/forcing_file_list = 'file_list_TestCase.txt'/g" $out_file
sed -i'.bak' 's/qv_is_spec_humidity = .False./qv_is_spec_humidity = .True./g' $out_file
sed -i'.bak' 's/tzone = 0.0/tzone = 1.0/g' $out_file
sed -i'.bak' 's/update_interval_rrtmg = 600/update_interval_rrtmg = 600/g' $out_file
sed -i'.bak' 's/qv_is_spec_humidity = .True./qv_is_spec_humidity = .True./g' $out_file
sed -i'.bak' 's/cfl_reduction_factor = 0.9/cfl_reduction_factor = 1.6/g' $out_file
sed -i'.bak' 's/RK3 = .False./RK3 = .True./g' $out_file
sed -i'.bak' 's/flux_corr = 0/flux_corr = 1/g' $out_file
sed -i'.bak' 's/h_order = 1/h_order = 3/g' $out_file
sed -i'.bak' 's/v_order = 1/v_order = 3/g' $out_file
sed -i'.bak' 's/sleve = .False./sleve = .True./g' $out_file
sed -i'.bak' 's/terrain_smooth_windowsize = 3/terrain_smooth_windowsize = 5/g' $out_file
sed -i'.bak' 's/terrain_smooth_cycles = 5/terrain_smooth_cycles = 100/g' $out_file
sed -i'.bak' 's/sleve_n = 1.2/sleve_n = 1.35/g' $out_file
sed -i'.bak' 's/decay_rate_L_topo = 2/decay_rate_L_topo = 1/g' $out_file
sed -i'.bak' 's/decay_rate_S_topo = 6/decay_rate_S_topo = 3/g' $out_file
sed -i'.bak' 's/dz_levels = 0.0/dz_levels = 23.0793700550371, 25.4054789829865, 27.9546004029731, 30.7456617662627, 33.7986658963874, 37.13462986434, 40.7754878622213, 44.7439504647213, 49.0633117863096, 53.7571952388465, 58.8492279502517, 64.3626335260366, 70.3197328568148, 76.7413432615544, 83.6460676036046, 91.0494673453666, 98.9631170549111, 107.393542879556, 116.341054166015, 125.798485877882, 135.749879770318, 146.169144288172, 157.018746480945, 168.248503199185, 179.79455242322, 191.578597373964, 203.507524314657, 215.473497662955, 227.354631108753, 239.016318976301, 250.313286722599, 261.092382801852, 271.196087038084, 280.46665561911, 288.750764024197, 295.904452287969, 301.798128624738, 306.321354381736, 309.387121454553, 310.935346604612/g' $out_file
rm "${out_file}.bak"
