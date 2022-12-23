# ARG detection using GROOT

[GROOT](https://github.com/will-rowe/groot) (**G**raphing **R**esistance **O**ut **O**f me**T**agenomes) detect the ARGs in metagenomic samples. 

## Installation
Use Conda:
```
conda install -c bioconda groot=1.1.2
```
## Creating singluarity image

```
Bootstrap: docker
From: centos:centos7.6.1810

%environment
    export PATH=$PATH:/opt/software/conda/bin
    source /opt/software/conda/bin/activate /opt/software/conenv


%post
    yum -y install epel-release wget which nano curl zlib-devel
    yum -y groupinstall "Development Tools"
    
    mkdir -p /opt/software
    cd /opt/software

    #Downloading miniconda3
    wget -c https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    #Installing miniconda3
    sh ./Miniconda3-latest-Linux-x86_64.sh -p /opt/software/conda -b

    /opt/software/conda/bin/conda config --add channels defaults
    /opt/software/conda/bin/conda config --add channels bioconda
    /opt/software/conda/bin/conda config --add channels conda-forge
    /opt/software/conda/bin/conda config --add channels biobakery
    
    /opt/software/conda/bin/conda create -y -p /opt/software/conenv -c bioconda groot=1.1.2 parallel sra-tools==2.8 fastqc==0.11.7 bbmap==37.90 multiqc seqkit==0.7.2 samtools==1.4 metacherchant==0.1.0
    /opt/software/conda/bin/conda clean -y --all
    source /opt/software/conda/bin/activate /opt/software/conenv
    cd /opt/software

%runscript
    exec groot "$@"
```
**IMAGE LOCATION**=`/qib/research-projects/cami/tiwari/groot/groot-1.1.2.simg`
## ARG Databases
### Get pre-clustered ARG database
Pre-clustered ARG database is only available for sequence identity 90%.
Download and index the pre-clustered database.
```
for i in {arg-annot,resfinder,card,groot-db,groot-core-db}; do groot get -d $i -o databases; groot index -m ./databases/$i".90" -i ./databases/$i".index" -w 100;done;

Note: -w = the readlength of the dataset 
```
## Profile ARG
Use runGroot.sh script to do resitome profiling in metagenome sample.
```
sh runGroot.sh -h
script usage: $0 [-f fwd-reads] [-r rev-reads] [-d indexDB] [-t threads] [-p covCutoff (0.97)]

## Run groot
sh runGroot.sh -f R1.fq.gz -r R2.fq.gz -d card.90.index -t 30 -p 0.97 >arg2.txt
```

## Summarizing groot reports
The groot reports of samples in single run/batch can be summarized by using the script grootreport2multiqc.py. The script will generate 4 output file. Whearas the main output is in MultiQC table format.

The script will estimated the total reads mapped to ARGs per sample, total number of ARGs detected per sample and the top N ARGs within a batch/run.

```
python3 grootreport2multiqc.py --help

usage: grootreport2multiqc.py [-h] [-i GROOT_REPORT [GROOT_REPORT ...]] [-s REPORT_SUFFIX] [-t TOPNARG] [-o OUTPUT]

Generate a MultiQC table

optional arguments:
  -h, --help            show this help message and exit
  -i GROOT_REPORT [GROOT_REPORT ...], --groot-report GROOT_REPORT [GROOT_REPORT ...]
                        Groot report txt files
  -s REPORT_SUFFIX, --report-suffix REPORT_SUFFIX
                        Suffix of the groot report files [default: .groot.txt]
  -t TOPNARG, --topNarg TOPNARG
                        Top N ARG in the run [default: 5]
  -o OUTPUT, --output OUTPUT
                        Output file [default: groot_mqc.txt]
```
**Expected output**

`groot_mqc.txt:` Summarized groot report in MultiQC table format. \
`final_report.tsv:` Summarized groot report in tsv format. \
`arg_prs_abs.tsv:` Presence absence matrix of ARGs. \
`groot_summary.tsv:` Groot raw summary after merging all the samples report.