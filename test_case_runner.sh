#!/bin/bash

# Define colors for output styling
BLUE='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

#Get location of HICAR repo
hicar_repo=$(readlink -f $1)

#get the location of a HICAR executable, should be in the bin directory
if [ ! -f $hicar_repo/bin/HICAR ]; then
	#check if rather HICAR_debug is in the bin directory
	if [ -f $hicar_repo/bin/HICAR_debug ]; then
		hicar_exe=$hicar_repo/bin/HICAR_debug
	else
		echo -e "${RED}HICAR executable not found in bin directory. Please check the path to the HICAR repo${NC}"
		echo -e "${RED}and ensure that 'make install' was run from the build directory.${NC}"
		exit 1
	fi
else
	hicar_exe=$hicar_repo/bin/HICAR
fi

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
				set -- "${hicar_repo}" "${script_list_string}"
				# Rebuild the script list
				IFS=',' read -ra script_list <<< "$2"
			fi
		fi
	done
fi

#First, make forcing file list
if [ ! -f $hicar_repo/tests/Test_Cases/input/file_list_TestCase.txt ]; then
	/${hicar_repo}/helpers/filelist_script.sh "${hicar_repo}/tests/Test_Cases/forcing/*" ${hicar_repo}/tests/Test_Cases/input/file_list_TestCase.txt
fi

#Now copy the necesarry supporting files to the input directory
if [ ! -f $hicar_repo/tests/Test_Cases/input/VEGPARM.TBL ]; then
	echo 'Copying .TBL files needed by NoahMP, which are found in'
	echo $hicar_repo/run
	echo 'to ${hicar_repo}/tests/Test_Cases/input'

	cp $hicar_repo/run/*.TBL $hicar_repo/tests/Test_Cases/input/
fi
# test for existence of the rrtmg_support and mp_support directories
if [ ! -d $hicar_repo/tests/Test_Cases/input/rrtmg_support ]; then
	cp -r $hicar_repo/run/rrtmg_support $hicar_repo/tests/Test_Cases/input/
fi
if [ ! -d $hicar_repo/tests/Test_Cases/input/mp_support ]; then
	cp -r $hicar_repo/run/mp_support $hicar_repo/tests/Test_Cases/input/
fi

#Generate default namelist 
default_file=$hicar_repo/tests/Test_Cases/input/default_hicar_options.nml
if [ -f $default_file ]; then
	rm $default_file
fi

echo 'Generating default namelist to $hicar_repo/tests/Test_Cases/input'
$hicar_exe --gen-nml $default_file

#Generate test case namelist files based on the namelist generation files in input/nml_gen_scripts
cd $hicar_repo/tests/Test_Cases/input

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
	export sys_np=$(sysctl -n hw.logicalcpu)
else
	export sys_np=$(nproc --all)
fi
 
# Use half of the available processors if we have a lot, otherwise use all
np=$(( sys_np/2 ))
np=$(( sys_np>8 ? np : sys_np ))
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
IFS=',' read -ra script_list <<< "$2"
for item in "${script_list[@]}"; do
	# Trim any whitespace
	item=$(echo "$item" | xargs)
	# append ".nml" to the end of the item
	nml_file="${item}.nml"
	# Check if the file is a regular file
	if [ -f "$nml_file" ]; then
		# Skip the default_hicar_options.nml file
		if [ ! $nml_file == *"default_hicar_options"* ]; then
			base_name=$(basename "$nml_file")
			base_name_no_ext="${base_name%.nml}"

			# Run the HICAR executable with the current .nml file
			echo
			echo
			echo -e "Running test case: ${BLUE}$base_name_no_ext${NC}"
			echo -e "Output will be written to ${BLUE}$base_name_no_ext.out${NC} and ${BLUE}$base_name_no_ext.err${NC}"


			# check if $mpiexec_path is set
			if [ ! -z "$mpiexec_path" ]; then
				echo -e "${GREEN}Using mpiexec to run HICAR${NC}"
				# Start HICAR with output redirected to files
				$mpiexec_path -np $np $hicar_exe $nml_file 1>$base_name_no_ext.out 2>$base_name_no_ext.err &
				hicar_pid=$!

			else
				# Check if srun is available
				if command -v srun &> /dev/null; then
					echo -e "${GREEN}Using srun to run HICAR${NC}"
					srun -N 1 -n $np $SRUN_FLAGS $hicar_exe $nml_file 1>$base_name_no_ext.out 2>$base_name_no_ext.err &
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
				if [ ! -z "$mpiexec_path" ] && [ $wait_counter -gt 300 ]; then
					# Check if the process is still running
					if kill -0 $hicar_pid 2>/dev/null; then
						# inform the user that the process is still running,
						# but not producing output. This is likely a hang
						echo
						echo -e "${RED}HICAR is still running, but has not written to stdout in the last 5 minutes. This may indicate a hang.${NC}"
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
			# NOTE: output verification is intentionally NOT done here. This runner
			# only RUNS integration cases (it verifies they complete without error).
			# Comparing the produced output against the blessed reference is a
			# separate step: tests/test_regression.sh recompiles the blessed commit
			# (tests/regression_commit.txt), regenerates the reference output, and
			# diffs it against these integration outputs with tests/compare_outputs.py.
			echo "-------------------------------------------------------"
		fi
	else
		echo -e "${RED}File $nml_file not found. Skipping test case ${BLUE}$item${NC}${RED}.${NC}"
	fi
done

echo "Finished running test cases"
