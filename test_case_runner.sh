#!/bin/bash

# Define colors for output styling
BLUE='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

#Get location of HICAR repo
hicar_repo=$(readlink -f $1)

#Second argument is a comma separated list of the test cases to run
#If a list is provided, check each test case to see if it contains
# "_restart" anywhere in the name. If it does, obtain the rest of 
#the test case name by removing the "_restart" part. Check if this 
#test case is in the list of test cases. If yes, ensure that it is 
#before the "_restart" test case. If not, inform the user and error
if [ $# -gt 1 ]; then
	IFS=',' read -ra script_list <<< "$2"
	for item in "${script_list[@]}"; do
		# Trim any whitespace
		item=$(echo "$item" | xargs)
		if [[ $item == *"_restart"* ]]; then
			base_name_no_ext="${item%_restart*}"
			if [[ ! " ${script_list[@]} " =~ " ${base_name_no_ext} " ]]; then
				echo -e "${RED}Test case ${base_name_no_ext} must be included in the list of test cases to run before ${item}${NC}"
				exit 1
			else
				# Move the base test case to the front of the list
				# to ensure that it is run first
				temp_list=()
				for entry in "${script_list[@]}"; do
					if [[ "$entry" != "$item" && "$entry" != "$base_name_no_ext" ]]; then
						temp_list+=("$entry")
					fi
				done
				script_list=("$base_name_no_ext" "$item" "${temp_list[@]}")
				# Rebuild the comma-separated list
				# to pass to the script
				# Remove any leading or trailing commas
				script_list_string=$(printf "%s," "${script_list[@]}")
				#Remove the last comma
				script_list_string=${script_list_string/%,}
				# Remove any leading or trailing spaces
				script_list_string=$(echo "$script_list_string" | xargs)
				# Pass the new list to the script
				set -- "$1" "$script_list_string"
				# Rebuild the script list
				IFS=',' read -ra script_list <<< "$2"
			fi
		fi
	done
fi

#First, make forcing file list
if [ ! -f ./input/file_list_TestCase.txt ]; then
	/$1/helpers/filelist_script.sh "forcing/*" input/file_list_TestCase.txt
fi

#Now copy the necesarry supporting files to the input directory
if [ ! -f ./input/VEGPARM.TBL ]; then
	echo 'Copying .TBL files needed by NoahMP, which are found in'
	echo $hicar_repo/run
	echo 'to ./input'

	cp $hicar_repo/run/*.TBL ./input/
fi
# test for existence of the rrtmg_support and mp_support directories
if [ ! -d ./input/rrtmg_support ]; then
	cp -r $hicar_repo/run/rrtmg_support ./input
fi
if [ ! -d ./input/mp_support ]; then
	cp -r $hicar_repo/run/mp_support ./input
fi

#Generate default namelist 
default_file=input/default_hicar_options.nml
if [ -f $default_file ]; then
	rm $default_file
fi

echo 'Generating default namelist to ./input'
$hicar_repo/bin/HICAR --gen-nml $default_file

#Generate test case namelist files based on the namelist generation files in input/nml_gen_scripts
cd input

#Get just the file name of the default namelist
default_file=$(basename "$default_file")

# Loop over all *.sh files in nml_gen_scripts
for script in nml_gen_scripts/*.sh; do
	# Check if the file is a regular file
	if [ -f "$script" ]; then
		# the second argument is an optional comma-separated list of script names.
		# If it is provided, see if the script is in the list
		if [ $# -gt 1 ]; then
			base_name=$(basename "$script")
			base_name_no_ext="${base_name%.sh}"
			script_found=false
			# Split the comma-separated list into an array
			IFS=',' read -ra script_list <<< "$2"
			for item in "${script_list[@]}"; do
				# Trim any whitespace
				item=$(echo "$item" | xargs)
				if [ "$item" == "$base_name_no_ext" ]; then
					script_found=true
					break
				fi
			done
		fi

		if [[ $# -eq 1 ]] || [ $script_found == true ]; then
			# Get the base name of the script (without the directory)
			base_name=$(basename "$script")
			# Remove the .sh extension
			base_name_no_ext="${base_name%.sh}"
			# Create the output file name
			out_file="${base_name_no_ext}.nml"

			cp $default_file $out_file

			# Run the script, passing the file just created to be used as a template
			./$script $out_file

            base_name_no_ext_no_rst="${base_name_no_ext%_restart}"

			# Check if the output and restart folders already exist, in which case delete them
			# This ensures that no old output or restart files are used
			if [ -d ../output/$base_name_no_ext_no_rst ]; then
				echo -e "${RED}Output folder already exists. Deleting it.${NC}"
				rm -rf ../output/$base_name_no_ext_no_rst
			fi
			if [ -d ../restart/$base_name_no_ext_no_rst ]; then
				echo -e "${RED}Restart folder already exists. Deleting it.${NC}"
				rm -rf ../restart/$base_name_no_ext_no_rst
			fi
			# make the output and restart folders which will be needed by the run
			mkdir -p ../output/$base_name_no_ext_no_rst
			mkdir -p ../restart/$base_name_no_ext_no_rst
		fi
	fi
done


# Once all of the .nml files have been created, run the HICAR executable
# with each of them
# detect if this is running on mac OS
if [[ "$OSTYPE" == "darwin"* ]]; then
	export np=$(sysctl -n hw.logicalcpu)
else
	export np=$(nproc --all)
fi

np=$((np/2))
np=$((np>2?np:2))
np=$((np<21?np:21))
export OMP_NUM_THREADS=1


echo "-------------------------------------------------------"

# Get path to mpiexec executable, ignoring any with "python" or "anaconda" in the path
# Find the first mpiexec in PATH that doesn't contain python or conda
mpiexec_path=""
IFS=':' read -ra PATH_DIRS <<< "$PATH"
for dir in "${PATH_DIRS[@]}"; do
	if [ -x "$dir/mpiexec" ] && ! [[ "$dir" =~ python|conda ]]; then
		mpiexec_path="$dir/mpiexec"
		break
	fi
done

if [ -z "$mpiexec_path" ]; then
	#check if srun is available
	if command -v srun &> /dev/null; then
		echo -e "${GREEN}Using srun to run HICAR${NC}"
		# Get any srun flags passed to the script
		SRUN_FLAGS=""
		for arg in "$@"; do
			if [[ "$arg" == -SRUN_FLAGS=* ]]; then
				# Extract everything after -SRUN_FLAGS=
				SRUN_FLAGS="${arg#-SRUN_FLAGS=}"
				# Remove surrounding quotes if present
				SRUN_FLAGS="${SRUN_FLAGS#\'}"
				SRUN_FLAGS="${SRUN_FLAGS%\'}"
				break
			fi
		done

	else
		echo -e "${RED}mpiexec not found. Please install mpiexec.${NC}"
		echo -e "${RED}If you are using a cluster with SLURM, pass your${NC}"
		echo -e "${RED}srun flags to the script.${NC}"
		echo -e "${RED}Example: ./test_case_runner.sh -SRUN_FLAGS='-A s4920'${NC}"
		exit 1
	fi
else
	echo -e "${GREEN}Using mpiexec from: $mpiexec_path${NC}"
fi

echo
echo -e "${GREEN}Using ${np} processors for test cases${NC}"
echo "-------------------------------------------------------"
for nml_file in *.nml; do
	# Check if the file is a regular file
	if [ -f "$nml_file" ]; then
		# Skip the default_hicar_options.nml file
		if [ ! $nml_file == *"default_hicar_options"* ]; then
			base_name=$(basename "$nml_file")
			base_name_no_ext="${base_name%.nml}"

			if [ $# -gt 1 ]; then
				script_found=false
				# Split the comma-separated list into an array
				IFS=',' read -ra script_list <<< "$2"
				for item in "${script_list[@]}"; do
				# Trim any whitespace
				item=$(echo "$item" | xargs)
				if [ "$item" == "$base_name_no_ext" ]; then
					script_found=true
					break
				fi
				done
			fi

			if [[ $# -eq 1 ]] || [ $script_found == true ]; then

				# Run the HICAR executable with the current .nml file
				echo
				echo
				echo -e "Running test case: ${BLUE}$base_name_no_ext${NC}"
				echo -e "Output will be written to ${BLUE}$base_name_no_ext.out${NC} and ${BLUE}$base_name_no_ext.err${NC}"


				# check if $mpiexec_path is set
				if [ ! -z "$mpiexec_path" ]; then
					echo -e "${GREEN}Using mpiexec to run HICAR${NC}"
					# Start HICAR with output redirected to files
					$mpiexec_path -np $np $hicar_repo/bin/HICAR $nml_file 1>$base_name_no_ext.out 2>$base_name_no_ext.err &
					hicar_pid=$!

				else
					# Check if srun is available
					if command -v srun &> /dev/null; then
						echo -e "${GREEN}Using srun to run HICAR${NC}"
						srun $SRUN_FLAGS $hicar_repo/bin/HICAR $nml_file 1>$base_name_no_ext.out 2>$base_name_no_ext.err &
						hicar_pid=$!
					else
						echo -e "${RED}srun not found.${NC}"
						exit 1
					fi
				fi
				
				echo
				echo -n "Initializing..."

				# Monitor the output file for progress
				last_line_count=0
				wait_counter=0
				total_last_lines=0
				while kill -0 $hicar_pid 2>/dev/null; do
					sleep 1
					if [ ! -z "$mpiexec_path"] && [$wait_counter -gt 60 ]; then
						# Check if the process is still running
						if kill -0 $hicar_pid 2>/dev/null; then
							# inform the user that the process is still running,
							# but not producing output. This is likely a hang
							echo
							echo -e "${RED}HICAR is still running, but has not written to stdout in the last minute. This may indicate a hang.${NC}"
							# kill the process
							kill -9 $hicar_pid
							exit 1
						fi
					fi
					if [ -f "$base_name_no_ext.out" ]; then
						total_current_lines=$(wc -l < "$base_name_no_ext.out")
						if [ $total_current_lines -eq $total_last_lines ]; then
							wait_counter=$((wait_counter + 1))
						else
							wait_counter=0
						fi
						total_last_lines=$total_current_lines
						# Get new Model Time lines
						current_lines=$(grep -a "^ *Model time" "$base_name_no_ext.out" | wc -l)
						if [ $current_lines -gt $last_line_count ]; then
							if [ $last_line_count -eq 0 ]; then
								# Overwrite initializing with "Running..."
								echo -e "\r\033[KRunning..."
							fi
							latest_line=$(grep -a "^ *Model time" "$base_name_no_ext.out" | tail -n 1)
							end_time=$(grep -a "^ *End  time" "$base_name_no_ext.out" | tail -n 1)

							echo -e "\r\033[K$latest_line"
							echo -n "$end_time"

							last_line_count=$current_lines
						fi
					fi
				done
				echo
				echo
				
				# Wait for process to complete and get exit code
				wait $hicar_pid
				hicar_status=$?
				
				# Check if the process completed successfully
				if [ $hicar_status -ne 0 ]; then
					echo -e "${RED}HICAR exited with error code $hicar_status${NC}"
				fi

				echo -e "Test Case: ${BLUE}$base_name_no_ext${NC} complete"
				# Check if the .sh file used to generate the .nml file
				# Ends with the line "CHECK OUTPUT", indicating that
				# we should call the python script check_output.py
				# to check the output
				if grep -q "#CHECK OUTPUT" "nml_gen_scripts/$base_name_no_ext.sh"; then
					echo
					echo -e "Checking output for ${BLUE}$base_name_no_ext${NC}"

					# move one layer up to the root directory with the python script
					cd ..
					#get the path to the python executable
					python_exe=$(which python)
					# check if python is installed
					if [ -z "$python_exe" ]; then
						#try python3
						python_exe=$(which python3)
						if [ -z "$python_exe" ]; then
							echo -e "${RED}Python is not installed, but a check is requested for test: ${BLUE}$base_name_no_ext${NC}{RED}. Please install Python.${NC}"
							exit 1
						fi
					fi
					# check if python has xarray, numpy, and netcdf4 installed
					if ! $python_exe -c "import xarray, numpy, netCDF4, dask" &> /dev/null; then
						PY_ENV_PATH=$(pwd)/venv
						echo
						echo -e "Python packages xarray, numpy, netCDF4, and dask are not installed"
						echo -e "Creating a virtual environment and installing them to:"
						echo -e "    ${BLUE}${PY_ENV_PATH}${NC}"
						echo "-------------------------------------------------------"
						mkdir -p $PY_ENV_PATH
						$python_exe -m venv ${PY_ENV_PATH}
						${PY_ENV_PATH}/bin/pip install numpy netCDF4 xarray dask
	                    export PYTHONPATH=${PY_ENV_PATH}:$ENV{PYTHONPATH} 
						# Get the path to the python executable in the virtual environment
						python_exe=${PY_ENV_PATH}/bin/python
						echo "-------------------------------------------------------"
						echo
					fi
					PATH_tmp=${PATH}
					export PATH=${PY_ENV_PATH}/bin:$ENV{PATH} 
					$python_exe check_output.py $base_name_no_ext
					export PATH=$PATH_tmp

					check_result=$?

					cd input
				fi
				echo "-------------------------------------------------------"
			fi
		fi
	fi
done

echo "Finished running test cases"
