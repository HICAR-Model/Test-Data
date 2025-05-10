#!/usr/bin/env python3
import xarray as xr
import numpy as np
import sys
import os
import glob

class bcolors:
    BLUE='\033[0;36m'
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    NC='\033[0m' # No Color
    
def calculate_percent_diff(var1, var_ref):

    # threshold = np.mean(np.abs(var_ref))*1e-4
    threshold = 1e-6
    """Calculate the absolute percent difference between two arrays."""
    # Avoid division by zero by adding a small value where zero
    var1_no_zero = np.where((var1 > threshold) | (var1 < 0), var1, threshold)
    var1_no_zero = np.where((var1 < -threshold) | (var1 > 0), var1_no_zero, -threshold)
    # var_ref_no_zero = np.where((var1 > threshold) | (var1 < 0), var_ref, threshold)
    # var_ref_no_zero = np.where((var1 < -threshold) | (var1 > 0), var_ref_no_zero, -threshold)

    # var1_no_zero = np.mean(var1_no_zero)
    # var_ref_no_zero = np.mean(var_ref_no_zero)
    percent_diff = np.abs((var1 - var_ref) / var1_no_zero) * 100.0

    # get mean of var1, excluding zero values
    var1_sum = np.sum(np.abs(var1))
    var1_count = np.count_nonzero(var1)
    if var1_count > 0:
        var1_mean = var1_sum / var1_count
    else:
        var1_mean = 0.0

    # mask regions where the difference is less than 1% of the mean
    percent_diff = np.where(np.abs(var1-var_ref) > 0.01*var1_mean, percent_diff, 0.0)

    # percent_diff = np.abs(var1-var_ref)*100
    return percent_diff

def main():

    # Check if the script is run with the correct number of arguments
    if len(sys.argv) != 2:
        print("Usage: python check_output.py <base_name>")
        return 1
    base_name = sys.argv[1]

    # Define file paths
    reference_file = "output/"+base_name+".nc"
    output_file = "output/"+base_name+"/Gaudergrat_250m_2017-02-14_00-00-00.nc"

    # if the pattern "_restart" appears in base_name, remove it from paths
    if "_restart" in base_name:
        reference_file = reference_file.replace("_restart", "")
        output_file = output_file.replace("_restart", "")

    # Check if files exist
    output_matches = glob.glob(output_file)
    if not output_matches:
        print(f"Error: {output_file} does not exist")
        return 1
    
    if not os.path.exists(reference_file):
        print(f"Error: {reference_file} does not exist")
        return 1
    
    # Open NetCDF files with xarray
    try:
        ds_output = xr.open_dataset(output_file)
        ds_reference = xr.open_dataset(reference_file)
    except Exception as e:
        print(f"Error opening NetCDF files: {e}")
        return 1
    
    # Variables to check
    variables = ['u', 'v', 'w', 'temperature', 'pressure', 'qv', 'precipitation', 'hfss', 'hfls', 'lwtr', 'swtd', 'swtb']
    
    # Flag to track if any variable exceeds threshold
    error_flag = False
    threshold = 5.0  # 5% threshold
    
    print(f"Comparing variables between {bcolors.BLUE}"+output_file+f"{bcolors.NC} and {bcolors.BLUE}"+reference_file+f"{bcolors.NC}")
    print("-" * 60)
    
    # Check each variable
    for var_name in variables:
        try:
            if var_name not in ds_output or var_name not in ds_reference:
                print(f"{bcolors.RED}ERROR: Variable {var_name} not found in one or both files{bcolors.NC}")
                error_flag = True
                continue
            
            var_reference = ds_reference[var_name].values[:-1,...]
            var_output = ds_output[var_name].values[:var_reference.shape[0],...]

            # Calculate percent difference
            percent_diff = calculate_percent_diff(var_output, var_reference)
            max_diff = np.max(percent_diff)
            
            # Print results
            print(f"{var_name:15s}: Max absolute percent difference = {max_diff:.4f}%")
            
            # Check if difference exceeds threshold
            if max_diff > threshold:
                print(f"  {bcolors.RED}ERROR: {var_name} exceeds the {threshold}% threshold{bcolors.NC}")

                # For offending fields, add to a collection to be saved later
                # Create the output directory if it doesn't exist
                os.makedirs(f"output/{base_name}", exist_ok=True)
                
                # Initialize the diff dataset if it's the first offending variable
                if not hasattr(main, 'ds_diff'):
                    main.ds_diff = xr.Dataset(coords={
                        "time": ds_reference.time[:-1],
                        "level": ds_reference.level if "level" in ds_reference.dims else None,
                        "lat": ds_reference.lat,
                        "lon": ds_reference.lon
                    })
                # Add this variable's diff to the dataset
                if len(percent_diff.shape) == 3:
                    main.ds_diff[f"{var_name}_diff"] = xr.DataArray(
                        percent_diff, 
                        dims=["time", "lat", "lon"]
                    )
                elif len(percent_diff.shape) == 4:
                    if (percent_diff.shape[2] == ds_reference.sizes['lat_v']):
                        main.ds_diff[f"{var_name}_diff"] = xr.DataArray(
                            percent_diff, 
                            dims=["time", "level", "lat_v", "lon"]
                        )

                    elif (percent_diff.shape[3] == ds_reference.sizes['lon_u']):
                        print(f"MAKING U")
                        main.ds_diff[f"{var_name}_diff"] = xr.DataArray(
                            percent_diff, 
                            dims=["time", "level", "lat", "lon_u"]
                        )
                    else:
                        main.ds_diff[f"{var_name}_diff"] = xr.DataArray(
                            percent_diff, 
                            dims=["time", "level", "lat", "lon"]
                        )
                
                # Write the dataset to file after adding each variable
                output_diff_file = f"output/{base_name}/differences.nc"
                main.ds_diff.to_netcdf(output_diff_file, mode='w')

                error_flag = True
                
        except Exception as e:
            print(f"{bcolors.RED}Error comparing {var_name}: {e}{bcolors.NC}")
            error_flag = True
    
    # Close files (xarray automatically closes files when datasets go out of scope,
    # but it's good practice to close them explicitly)
    ds_output.close()
    ds_reference.close()
    
    print("-" * 60)
    if error_flag:
        print(f"{bcolors.RED}Test FAILED for {bcolors.BLUE}"+base_name+f"{bcolors.RED}: One or more variables exceed the allowed difference threshold{bcolors.NC}")
        return 1
    else:
        print(f"{bcolors.GREEN}Output verification successful for {bcolors.BLUE}"+base_name+f"{bcolors.NC}")
        return 0

if __name__ == "__main__":
    sys.exit(main())