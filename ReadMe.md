# ARG detection using GROOT

[GROOT](https://github.com/will-rowe/groot) (**G**raphing **R**esistance **O**ut **O**f me**T**agenomes) detect the ARGs in metagenomic samples. Here, we build a wrapper around Groot to run the whole pipeline in one go (using paired-end data) and extend to use a custom AMR genes database (in fasta format). Later summarize the ARGs profile from multisample with `report2multiqc.py`.


## Installation
Use Micromamba [(installation)](https://mamba.readthedocs.io/en/latest/installation/micromamba-installation.html):
```
micromamba create -n metARGroot -f ./envs/env.yaml
```
## Creating singularity image
To create a singularity image with `./env/singularity.def`:
```
sudo singularity build metARGRoot__v0.1.0.simg ./env/singularity.def
```

## How to run metARGroot
Consists of two modes:
```
sh run_metARGroot.sh -h

Available modes:
 * create_db: Build a new database from a sequence file
 * predictARG: Predict the ARGs
For more information, run runGroot.sh -m <mode> -h
```
## Build AMR database:
To build an AMR database use  mode (-m) **create_db**. Either use already clustered AMR databases or provide a custom AMR genes file in fasta format.
This will provide a clustered-database.
```
sh run_metARGroot.sh -h

Usage: run_metARGroot.sh -m create_db -s DB_SEQ
    -m mode      Operation mode: create_db
    -s DB_SEQ    Build database from sequence file 
                 (OR)
    -d DB_NAME   Download pre-clustered database
Available database names (-d): arg-annot|resfinder|card|groot-db|groot-core-db
```
## Predict ARGs:
To predict the ARGs by using the database built in above use the mode (-m) **predictARG**.
```
sh run_metARGroot.sh -m predictARG -h

Usage: run_metARGroot.sh -m predictARG [-f fwd_reads] [-r rev_reads] [-p db_path] [-t threads] [-c covCutoff] [-o output]
    -m mode      Operation mode: predictARG
    -f FWD_READS Forward reads file (required)
    -r REV_READS Reverse reads file (required)
    -p DB_PATH   Path to indexed or clustered-MSA database (required)
    -t THREADS   Number of threads
    -c CovCutoff Coverage cutoff (default: 0.95)
    -o OUTPUT    Output file name
```

## Summarizing Groot reports
The Groot reports of samples in a single run/batch can be summarized using the script `grootreport2multiqc.py`. The script will generate 4 output files. At the same time, the main output is in MultiQC table format.

The script will estimate the total reads mapped to ARGs per sample, the total number of ARGs detected per sample and the top N ARGs within a batch/run.

```
python3 report2multiqc.py --help

usage: report2multiqc.py [-h] [-i GROOT_REPORT [GROOT_REPORT ...]] [-s REPORT_SUFFIX] [-t TOPNARG] [-o OUTPUT]

Generate a MultiQC table

optional arguments:
  -h, --help            show this help message and exit
  -i GROOT_REPORT [GROOT_REPORT ...], --groot-report GROOT_REPORT [GROOT_REPORT ...]
                        Groot report txt files
  -s REPORT_SUFFIX, --report-suffix REPORT_SUFFIX
                        Suffix of the Groot report files [default: .groot.txt]
  -t TOPNARG, --topNarg TOPNARG
                        Top N ARG in the run [default: 5]
  -o OUTPUT, --output OUTPUT
                        Output file [default: groot_mqc.txt]
```
**Expected output**

`groot_mqc.txt:` Summarized Groot report in MultiQC table format. \
`final_report.tsv:` Summarized Groot report in tsv format. \
`arg_prs_abs.tsv:` Presence absence matrix of ARGs. \
`groot_summary.tsv:` Groot raw summary after merging all the samples report.
