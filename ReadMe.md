# ARG detection using GROOT

[GROOT](https://github.com/will-rowe/groot) (**G**raphing **R**esistance **O**ut **O**f me**T**agenomes) detect the ARGs in metagenomic samples. 

## Installation
Use Conda:
```
conda install -c bioconda groot=1.1.2
```
## Creating singularity image
To create a singularity image with `./env/singularity.def`:
```
sudo singularity build metaARGRoot__v0.1.0.simg ./env/singularity.def
```

## ARG Databases
### Get a pre-clustered ARG database
The pre-clustered ARG database is only available for sequence identity 90%.
Download and index the pre-clustered database.
```
for i in {arg-annot,resfinder,card,groot-db,groot-core-db}; do groot get -d $i -o databases; groot index -m ./databases/$i".90" -i ./databases/$i".index" -w 100;done;

Note: -w = the read-length of the dataset 
```
## Profile ARG
Use runGroot.sh script to do resitome profiling in the metagenome sample.
```
sh runGroot.sh -h
script usage: $0 [-f fwd-reads] [-r rev-reads] [-d indexDB] [-t threads] [-p covCutoff (0.97)]

## Run Groot
sh runGroot.sh -f R1.fq.gz -r R2.fq.gz -d card.90.index -t 30 -p 0.97 >arg2.txt
```

## Summarizing Groot reports
The Groot reports of samples in a single run/batch can be summarized using the script grootreport2multiqc.py. The script will generate 4 output files. At the same time, the main output is in MultiQC table format.

The script will estimate the total reads mapped to ARGs per sample, the total number of ARGs detected per sample and the top N ARGs within a batch/run.

```
python3 grootreport2multiqc.py --help

usage: grootreport2multiqc.py [-h] [-i GROOT_REPORT [GROOT_REPORT ...]] [-s REPORT_SUFFIX] [-t TOPNARG] [-o OUTPUT]

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
