#!/bin/bash

## Bash script to run groot.
## Download the ARG databases.
## Index the ARG databases
## Run the ARG profiling

# Image path
#IMG="/home/ubuntu/cami/tiwari/groot/groot-1.1.2.simg"
#IMG="/qib/platforms/Informatics/transfer/outgoing/singularity/groot-1.1.2.simg"
#SINGULARITY="singularity exec $IMG"
#DB_LOC="/qib/research-projects/cami/tiwari/groot/groot_db"

DB_OPTIONS="arg-annot|resfinder|card|groot-db|groot-core-db" # List of preclustered databases.
mode="" ##Variable to store the mode (create_db or run_groot)

# Help message for create_db mode
create_db_help() {
    echo "Usage: $(basename $0) -m create_db -s DB_SEQ"
    echo "    -m mode      Operation mode: create_db"
    echo "    -s DB_SEQ    Build database from sequence file \n\t\t (OR)"
    echo "    -d DB_NAME   Download pre-clustered database"
    echo "Available database names (-d): $DB_OPTIONS"
}

# Help message for predictARG mode
predictARG_help() {
    echo "Usage: $(basename $0) -m predictARG [-f fwd_reads] [-r rev_reads] [-p db_path] [-t threads] [-c covCutoff] [-o output]"
    echo "    -m mode      Operation mode: predictARG"
    echo "    -f FWD_READS Forward reads file (required)"
    echo "    -r REV_READS Reverse reads file (required)"
    echo "    -p DB_PATH   Path to indexed or clustered-MSA database (required)"
    echo "    -t THREADS   Number of threads"
    echo "    -c CovCutoff Coverage cutoff (default: 0.95)"
    echo "    -o OUTPUT    Output file name"
}

# Run predictARG
run_predictARG() {
    # Setting default value for the coverage
    if [ -z "$cov" ]; then
        covCutoff=0.95
    else
        covCutoff="$cov"
    fi
    echo "coverage $covCutoff" >&2
    
    ## Predict ARG using GROOT
    echo "Predicting ARG on $fwd and $rev"
    mkdir -p "ARG-results" ## Output directory
    gunzip -c "$fwd" "$rev"| groot align -i "$db_path/db.index" -p "$threads"| groot report -c $covCutoff >"ARG-results/$output.tsv"
    echo "ARG prediction report: ARG-results/$output.tsv"
}

while getopts ':m:f:r:s::d::p:t:c:o:h' opt;
do
 case "$opt" in
   m) mode=${OPTARG};;
   f) fwd=${OPTARG};;
   r) rev=${OPTARG};; 
   d) db_name=${OPTARG};;
   s) db_seq=${OPTARG};;
   p) db_path=${OPTARG};;
   t) threads=${OPTARG};;
   c) cov=${OPTARG};;
   o) output=${OPTARG};;
   h)
        if [ -z "$mode" ]; then
            echo "Available modes:" >&2
            echo "  create_db: Build a new database from a sequence file" >&2
            echo "  predictARG: Predict the ARGs" >&2
            echo "For more information, run $(basename $0) -m <mode> -h" >&2
        elif [ "$mode" = "create_db" ]; then
            create_db_help
        elif [ "$mode" = "predictARG" ]; then
            predictARG_help
        else
            echo "Error: Invalid mode specified." >&2
            echo "Available modes: create_db, predictARG" >&2
        fi
        exit 0
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
    :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
 esac
done
shift $((OPTIND-1))
# Forward Read check

# Check if the mode is set
if [ -z "$mode" ]; then
    echo "Error: Operation mode (-m) not specified" >&2
    exit 1
fi

# MODE: CREATE DATABASE
if [ "$mode" = "create_db" ] && [ -z "$db_seq" ] && [ -z "$db_name" ]; then
    echo "Error: Either sequence file (-s) or database name (-d) must be provided for create_db mode" >&2
    exit 1

elif [ "$mode" = "create_db" ] && [ ! -z "$db_seq" ]; then
    ## Check if the sequence file exists.
    if [ ! -f "$db_seq" ]; then
        echo "Error: Sequence file '$db_seq' does not exist" >&2
        exit 1
    else
        echo "Sequence file $db_seq found"
        mkdir -p "custom-groot-db/cluster_msa"
        vsearch --cluster_size "$db_seq" --id 0.90 --msaout custom-groot-db/cluster_msa/MSA.tmp
        awk '!a[$0]++ {of="./custom-groot-db/cluster_msa/cluster-" ++fc ".msa"; print $0 >> of ; close(of)}' RS= ORS="\n\n" ./custom-groot-db/cluster_msa/MSA.tmp && rm ./custom-groot-db/cluster_msa/MSA.tmp
        echo "DB_PATH (-p): $PWD/custom-groot-db/cluster_msa"
        echo "Run 'sh runARGroot.sh -m predictARG -h' to predict ARG"
    fi

elif [ "$mode" = "create_db" ] && [ ! -z "$db_name" ]; then
    # Download the clustered database
    mkdir -p "clustered-groot-db"
    echo "Download and unpacking database: $db_name"
    groot get -d "$db_name" -o "clustered-groot-db" &>/dev/null
    echo "DB_PATH (-p): $PWD/clustered-groot-db/$db_name.90"
    echo "Run 'sh runARGroot.sh -m predictARG -h' to predict ARG"

# MODE: INDEX DB AND GROOT.
elif [ "$mode" = "predictARG" ]; then
    if [ -f "$fwd" ] && [ -f "$rev" ]; then
        ## Reference database check
        if [ -d  "$db_path"  ]; then
            if [ ! -f "$db_path/groot.gg" ] || [ ! -f "$db_path/groot.lshe" ]; then
                ## Create index at a estimated window-length(-w) ~= max read length
                echo "Creating index database"
                read_length=$(zcat $fwd | awk 'NR%4==2 {if (length($1) > max) max=length($1)} END {print max}')
                groot index -m "$db_path" -i "$db_path/db.index" -w $read_length
                echo "Database created successfully."
                
                ## Predict ARG using GROOT
                run_predictARG
            else
                echo "Indexed database already exists $db_path"
                ## Predict ARG using GROOT
                run_predictARG
            fi

        else
            echo "Error: Missing database at $db_path"
            exit 1
        fi
    else
        echo "Error: Forward (-f) and/or reverse (-r) are missing" >&2
        exit 1
    fi
else
   echo "Error: Invalid operation mode specified" >&2
   exit 1
fi
