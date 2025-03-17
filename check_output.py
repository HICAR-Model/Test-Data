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
    
def calculate_percent_diff(var1, var2):
    """Calculate the absolute percent difference between two arrays."""
    # Avoid division by zero by adding a small value where var2 is zero
    denominator = np.where(np.abs(var2) > 1e-10, var2, 1e-10)
    percent_diff = np.abs((var1 - var2) / denominator) * 100.0
    return percent_diff

def main():

    # Check if the script is run with the correct number of arguments
    if len(sys.argv) != 2:
        print("Usage: python check_output.py <base_name>")
        return 1
    base_name = sys.argv[1]

    # Define file paths
    output_file = "output/"+base_name+"/Gaudergrat_250m*.nc"
    reference_file = "output/"+base_name+".nc"
    
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
        ds_output = xr.open_mfdataset(output_file)
        ds_reference = xr.open_mfdataset(reference_file)
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
            
            var_output = ds_output[var_name].values
            var_reference = ds_reference[var_name].values
            
            # Calculate percent difference
            percent_diff = calculate_percent_diff(var_output, var_reference)
            max_diff = np.max(percent_diff)
            
            # Print results
            print(f"{var_name:15s}: Max absolute percent difference = {max_diff:.4f}%")
            
            # Check if difference exceeds threshold
            if max_diff > threshold:
                print(f"  {bcolors.RED}ERROR: {var_name} exceeds the {threshold}% threshold{bcolors.NC}")
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