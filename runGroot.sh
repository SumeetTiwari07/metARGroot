#!/bin/bash

## Bash script to run groot.
## Download the ARG databases.
## Index the ARG databases
## Run the ARG profiling

# Image path
#IMG="/home/ubuntu/cami/tiwari/groot/groot-1.1.2.simg"
IMG="/qib/platforms/Informatics/transfer/outgoing/singularity/groot-1.1.2.simg"
SINGULARITY="singularity exec $IMG"
DB_LOC="/qib/research-projects/cami/tiwari/groot/groot_db"

while getopts ':f:r:d:t:p:o:' run;
do
 case "${run}" in
   f) fwd=${OPTARG};;
   r) rev=${OPTARG};; 
   d) idx=${OPTARG};;
   t) threads=${OPTARG};;
   p) cov=${OPTARG};;
   o) output=${OPTARG};;
   ?)
    echo "script usage: $(basename \$0) [-f fwd-reads] [-r rev-reads] [-d indexDB] [-t threads] [-p covCutoff (0.97)]" >&2
    echo "# List of indexDB\nGROOT: groot-db.90.index"
    exit 1
   ;;
 esac
done
shift $((OPTIND-1))
# Forward Read check

if [ -f "$fwd" ]; then
    echo "$fwd exist.\n" >&2
else
    echo "$fwd does not found\n" >&2
    exit 0;
fi

# Reverse read check
if [ -f "$rev" ]; then
    echo "$rev exist\n" >&2
else
    echo "$frev does not found\n" >&2
    exit 0;
fi

# Reference database check
if [ -d "$DB_LOC/$idx" ]; then
    echo "$DB_LOC/$idx found\n" >&2
else
    echo "$DB_LOC/$idx not found\n" >&2
    exit 0;
fi

# Setting default value for the coverage
if [ -z "$cov" ]; then
    covCutoff=0.95
else
    covCutoff="$cov"
fi
echo "coverage $covCutoff" >&2

# Run groot
echo "Running Groot !!!" >&2
gunzip -c "$fwd" "$rev"|$SINGULARITY groot align -i "$DB_LOC/$idx" -p "$threads"|$SINGULARITY groot report -c $covCutoff >&1
