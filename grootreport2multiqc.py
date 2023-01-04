#!/usr/bin/env python3

"""
Combine groot report output and generate MultiQC ready table.
Receive a list of *.groot.txt files.

Outputs:
1) groot_mqc.txt: final output in MultQC format.
2) groot_summary.tsv: Merged all groot reports in the run/batch. \
    with additional columns: 'GeneSymbol'\t'TotalReadCount'\t'TotalARGCount'\t'Frequency'\t'ARGCount'
3) final_report.tsv: final output in tsv format (with top N genes).
4) arg_prs_abs.tsv: Presence absence of each arg across the sample.
"""
import argparse
import os
import pandas as pd
from itertools import product

# Initiating data frames.
df1=pd.DataFrame()
sample_names=list()

def beautifyReport(report):
    '''
    Extract the GeneSymbol from groot report
    Add GeneSymbol back to the report.
    '''
    report = report[[4, 0, 1, 2, 3]]
    report = report.rename(columns={4:"SampleID", 0:"ARG", 1:"ReadCount", 2:"GeneLength", 3:"Coverage"})
    report.reset_index(inplace=True, drop=True) # Reset and drop index
    report['GeneSymbol']=report['ARG']
    for row in report.itertuples(index = True):
        
        arg = getattr(row, 'GeneSymbol')
        idx = getattr(row, 'Index')
        
        if "groot-db_ARGANNOT" in arg:
            gene = arg.replace(":", "__").split("__")[1]
            report.at[idx,'GeneSymbol']=gene
        elif "groot-db_RESFINDER" in arg:
            gene = arg.split("_")[3:5]
            gene = "_".join(gene)
            report.at[idx,'GeneSymbol']=gene
        elif "groot-db_CARD" in arg:
            gene = arg.split("|")[-2:]
            gene = "|".join(gene)
            report.at[idx,'GeneSymbol']=gene
        else:
            report.at[idx,'GeneSymbol']=arg

    return report

def addstats(df, sample_names, N):
    '''
    Estimate Total reads mapped to ARGs per sample
    Number of ARGs dectected per sample
    Frequency of a ARG in single run/batch of samples.
    Estimate top N ARGs in the run/bactch of samples.
    '''
    df['TotalReadCount'] = df.groupby('SampleID').ReadCount.transform('sum') # Total readmapped per sample
    df['TotalARGCount'] = df.groupby('SampleID').SampleID.transform('count') # Number of ARG detected per sample
    df['Frequency'] = df.groupby('GeneSymbol').GeneSymbol.transform('count') # Frequency of each ARG in single Run.
    df['ARGCount'] = df.groupby(['SampleID', 'GeneSymbol']).ARG.transform('count') # Each ARG count per sample
    
    # Top N genes in the run
    topNgenes = df.sort_values(by=['Frequency'], ascending=False)
    topNgenes.drop_duplicates(subset="GeneSymbol", keep='first', inplace=True)
    topNgenes = topNgenes.head(N)[['GeneSymbol']]

    # ARG presence absence matrix per sample.
    stats_file = df.pivot(index=['SampleID','TotalReadCount','TotalARGCount'], columns='GeneSymbol', values='ARGCount')
    stats_file = stats_file.rename_axis(['SampleID', 'TotalReadCount','TotalARGCount']).reset_index()

    # Adding sample with no ARGs detected
    for idx, val in enumerate(sample_names):
        df_zero=pd.DataFrame(0, index=range(1), columns=list(stats_file.columns))
        df_zero['SampleID']=val
        stats_file=pd.concat([stats_file,df_zero])
    stats_file.fillna(0, inplace=True) # replacing na with zero

    return stats_file, topNgenes

def filterGenes(stats, genes):
    '''
    Create final report with showing top N ARGs presence across the samples.
    '''
    col2extract=stats.columns.to_list()[0:3]     
    [col2extract.append(i) for i in genes['GeneSymbol'].to_list()]
    finalReport = stats.filter(items=col2extract)
    return finalReport

def crearteArgdescription(summary):
    arg_dicts = zip(summary.GeneSymbol,summary.ARG)
    arg_dicts = list(arg_dicts)
    arg_dicts = dict(arg_dicts)
    #arg_dicts['TotalReadCount'] = "Total reads mapped to ARGs within the sample"
    arg_dicts['TotalARGCount'] = "Total number of ARGs detected in the sample"
    return arg_dicts

def generateMultiqc(data, name, argdicts, N):
    '''
    Convert final report to MultiQC format.
    '''
    data = data.drop(columns={'TotalReadCount'}) # Drop column

    with open(name, "w") as f1:
        f1.write("# plot_type: \'table\'\n")
        f1.write("# section_name: \'ARG detection\'\n")
        f1.write(f"# description: \'Summary top {N} AMR genes found\'\n")
        f1.write("# pconfig:\n")
        f1.write("#     namespace: \'Cust Data\'\n")
        f1.write("# headers:\n")
        # Adding colname, tittle, description and format for each column in multiqc report
        x = ["Sample"]
        for idx, val in enumerate(list(data.columns)[1:]):
            f1.write(f"#     col{idx+1}:\n")
            f1.write(f"#        title: \'{val}\'\n")
            f1.write(f"#        description: \'{argdicts[val]}\'\n")
            f1.write("#        format: \'{:,.0f}\'\n")
            f1.write(f"#        placement: {100*(idx+1)}\n") # ordering columns
            x.append(f"col{idx+1}")
        
        f1.write("\t".join(x))
        f1.write("\n")
        # Adding the real data
        f1.write(data.to_csv(sep="\t", index=False, header=None))
    return

def writeOuput(summary, stats, final_report):
    '''
    Output files
    '''
    # Merged groot report
    summary.to_csv("groot_summary.tsv", sep="\t", index=False) # Merged report.
    
    # Stats file
    stats = stats.drop(columns={'TotalReadCount', 'TotalARGCount'})
    stats = stats.T
    stats.to_csv("arg_prs_abs.tsv", sep="\t", index=True, header=None) # ARG presene absence matrix.
    
    #Raw final report
    final_report.to_csv("final_report.tsv", index=False, sep="\t")
    return

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Generate a MultiQC table from Groot reports')
    parser.add_argument('-i', '--groot-report', help='Groot report txt files', nargs='+')
    parser.add_argument('-s', '--report-suffix', help='Suffix of the groot report files [default: %(default)s]', default='.groot.txt')
    parser.add_argument('-t', '--topNarg', type=int, help='Top N ARG in the run [default: %(default)s]', default=5)
    parser.add_argument('-o', '--output', help='Output file [default: %(default)s]', default='groot_mqc.txt')
    args = parser.parse_args()

    # Get input files.
    ''' Merging all the reports'''
    print('Merging all the reports\n')
    for file in args.groot_report:
        basename = os.path.basename(file).replace(args.report_suffix,"") # Geting the basename of files
        if os.path.getsize(file) > 0: # Check if file is not empty
            if df1.empty:
                df1 = pd.read_table(file, header=None)
                df1[4] = basename
            else:
                df2 = pd.read_table(file, header=None)
                df2[4] = basename
                df1 = pd.concat([df1,df2])
        else:
            sample_names.append(basename)
    
    print("Summarizing groot report: groot_summary.tsv")
    summary = beautifyReport(df1) # Report beautification

    print("Creating ARGs presence absence matrix: arg_prs_abs.tsv")
    stats, genes =  addstats(summary, sample_names, args.topNarg)

    print("Preparing final report: final_report.tsv")
    final_report = filterGenes(stats, genes)
    
    print(f"Preparing MultiQC report: {args.output}")
    # Create ARG description Dictionary
    argdicts = crearteArgdescription(summary)
    generateMultiqc(final_report, args.output, argdicts, args.topNarg)
    
    # Write all the output
    print("Writing all the outputs")
    writeOuput(summary, stats, final_report)

    print("Processing finished. Thank you!")

