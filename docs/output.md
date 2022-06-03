# nf-core/isoseq: Output

## Introduction

This document describes the output produced by the pipeline.

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using the following steps:

- [CCS](#ccs) - Generate CCS sequences
- [LIMA](#lima) - Remove primer sequences from CCS
- [ISOSEQ REFINE](#isoseq-refine) - Detect and remove chimerics reads
- [BAMTOOLS CONVERT](#bamtools-convert) - Convert bam file into fasta file
- [TAMA POLYA CLEAN UP](#tama-polya-clean-up) - Detect and trim polyA tails reads
- [GUNZIP](#gunzip) - Decompress FLNC fastas (uLTRA path only)
- [ULTRA or MINIMAP2](#ultra-minimap2) - Map FLNCs on genome
- [BIOPERL](#bioperl) - Remove spurious alignments (uLTRA path only, [Issue #11](https://github.com/ksahlin/ultra/issues/11))
- [SAMTOOLS SORT](#samtools-sort) - Sort alignment and convert sam file into bam file
- [TAMA FILE LIST](#tama-file-list) - Prepare list file for TAMA collapse
- [TAMA COLLAPSE](#tama-collapse) - Clean gene models
- [TAMA MERGE](#tama-merge) - Merge all annotations into one for each sample with TAMA merge
- [Pipeline information](#pipeline-information) - Report metrics generated during the workflow execution

### CCS

<details markdown="1">
<summary>Output files</summary>

- `01_PBCCS/`
  - `<sample>.chunk<X>.bam`: The CCS sequences
  - `<sample>.chunk<X>.bam.pbi`: The Pacbio index of CCS files
  - `<sample>.chunk<X>.metrics.json.gz`: Statistics for each zmws
  - `<sample>.chunk<X>.report.json`: General statistics about generated CCS sequences in json format
  - `<sample>.chunk<X>.report.txt`: General statistics about generated CCS sequences in txt format

</details>

[CCS](https://github.com/PacificBiosciences/ccs) generate a Circular Consensus Sequence from subreads. It reports the number of selected and discarded zmws and the reason why.

### LIMA

<details markdown="1">
<summary>Output files</summary>

- `02_LIMA/`
  - `<sample>.chunk<X>_flnc.json`: Metadata about generated xml file
  - `<sample>.chunk<X>_flnc.lima.clips`: Clipped sequences
  - `<sample>.chunk<X>_flnc.lima.counts`: Statistics about detected primers pairs
  - `<sample>.chunk<X>_flnc.lima.guess`: Statistics about detected primers pairs
  - `<sample>.chunk<X>_flnc.lima.report`: Detailed statistics on primers pairs for each sequence
  - `<sample>.chunk<X>_flnc.lima.summary`: General statistics about selected and rejected sequences
  - `<sample>.chunk<X>_flnc.primer_5p--primer_3p.bam`: Selected sequences
  - `<sample>.chunk<X>_flnc.primer_5p--primer_3p.bam.pbi`: Pacbio index of selected sequences
  - `<sample>.chunk<X>_flnc.primer_5p--primer_3p.consensusreadset.xml`: Selected sequences metadata

</details>

[LIMA](https://github.com/pacificbiosciences/barcoding/) clean generated CCS. It selects sequences containing valid pairs of primers and removed it.

### ISOSEQ REFINE

<details markdown="1">
<summary>Output files</summary>

- `03_ISOSEQ3_REFINE/`
  - `<sample>.chunk<X>.bam`: Sequences sequences
  - `<sample>.chunk<X>.bam.pbi`: Pacbio index of selected sequences
  - `<sample>.chunk<X>.consensusreadset.xml`: Metadata
  - `<sample>.chunk<X>.filter_summary.json`: Number of Full Length, Full Length Non Chimeric, Full Length Non Chimeric PolyA
  - `<sample>.chunk<X>.report.csv`: Primers and insert length of each read

</details>

[ISOSEQ REFINE](https://github.com/PacificBiosciences/IsoSeq) discard chimeric reads.

### BAMTOOLS CONVERT

<details markdown="1">
<summary>Output files</summary>

- `04_BAMTOOLS_CONVERT/`
  - `<sample>.chunk<X>.fasta`: The reads in fasta format.

</details>

[BAMTOOLS CONVERT](https://github.com/pezmaster31/bamtools) convert reads in BAM format into fasta format.

### TAMA POLYA CLEAN UP

<details markdown="1">
<summary>Output files</summary>

- `05_GSTAMA_POLYACLEANUP/`
  - `<sample>.chunk<X>_tama.fa.gz`: The polyA tail free reads.
  - `<sample>.chunk<X>_polya_flnc_report.txt.gz`: Length of removed tails.
  - `<sample>.chunk<X>_tama_tails.fa.gz`: Sequence of removed tails.

</details>

[GSTAMA_POLYACLEANUP](https://github.com/GenomeRIK/tama) TAMA cleanup remove polyA tails from the selected reads.

### GUNZIP

<details markdown="1">
<summary>Output files</summary>

- `06.1_GUNZIP/`
  - `<sample>.chunk<X>_tama.fa`: The polyA tail free reads uncompressed.

</details>

[GUNZIP](https://www.gnu.org/software/gzip/) Uncompress FLNCs for their alignment with uLTRA (gzip not handled by uLTRA yet).

### ULTRA or MINIMAP2

<details markdown="1">
<summary>Output files</summary>

- `06.2_ULTRA/` or `06_MINIMAP2/`
  - `<sample>.chunk<X>.sam`: The aligned reads.

</details>

[`MINIMAP2`](https://github.com/lh3/minimap2) or [`uLTRA`](https://github.com/ksahlin/ultra) aligns reads ont the genome.

### BIOPERL

<details markdown="1">
<summary>Output files</summary>

- `06.3_PERL_BIOPERL/`
  - `<sample>.chunk<X>_filtered.sam`: The aligned reads with spurious alignments removed.

</details>

[BIOPERL](https://bioperl.org/) Some CIGAR string sometimes with a gap (N). This can happen when using GFF file converted to GTF file. See [Issue #11](https://github.com/ksahlin/ultra/issues/11) from uLTRA repo.

### SAMTOOLS SORT

<details markdown="1">
<summary>Output files</summary>

- `07_SAMTOOLS_SORT/`
  - `<sample>.chunk<X>_sorted.bam`: The sorted aligned reads.

</details>

[SAMTOOLS SORT](http://www.htslib.org/doc/samtools-sort.html) sort the aligned reads and convert the sam file in bam file.

### TAMA COLLAPSE

<details markdown="1">
<summary>Output files</summary>

- `08_GSTAMA_COLLAPSE/`
  - `<sample>.chunk<X>_collapsed.bed`: This is a bed12 format file containing the final collapsed version of your transcriptome
  - `<sample>.chunk<X>_local_density_error.txt`: This file contains the log of filtering for local density error around the splice junctions
  - `<sample>.chunk<X>_polya.txt`: This file contains the reads with potential poly A truncation
  - `<sample>.chunk<X>_read.txt`: This file contains information for all mapped reads from the input SAM/BAM file.
  - `<sample>.chunk<X>_strand_check.txt`: This file shows instances where the sam flag strand information contrasted the GMAP strand information.
  - `<sample>.chunk<X>_trans_read.bed`: This file uses bed12 format to show the transcript model for each read based on the mapping prior to collapsing.This file uses bed12 format to show the transcript model for each read based on the mapping prior to collapsing.
  - `<sample>.chunk<X>_trans_report.txt`: This file contains collapsing information for each transcript
  - `<sample>.chunk<X>_varcov.txt`: This file contains the coverage information for each variant detected.
  - `<sample>.chunk<X>_variants.txt`: This file contains the variants called

</details>

[TAMA COLLAPSE](https://github.com/GenomeRIK/tama/wiki/Tama-Collapse) TAMA Collapse is a tool that allows you to collapse redundant transcript models in your Iso-Seq data.

### TAMA FILE LIST

<details markdown="1">
<summary>Output files</summary>

- `09_GSTAMA_FILELIST/`
  - `<sample>.tsv`: A tsv listing bed files to merge with TAMA merge

</details>

TAMA FILELIST is a home script for generating input file list for TAMA merge.

### TAMA MERGE

<details markdown="1">
<summary>Output files</summary>

- `10_GSTAMA_MERGE/`
  - `<sample>.bed`: This is the main merged annotation file.
  - `<sample>_gene_report.txt`: This contains a report of the genes from the merged file.
  - `<sample>_merge.txt`: This contains a bed12 format file which shows the coordinates of each input transcript matched to the merged transcript ID.
  - `<sample>_trans_report.txt`: This contains the source information for each merged transcript.

</details>

[TAMA MERGE](https://github.com/GenomeRIK/tama/wiki/Tama-Merge) TAMA Merge is a tool that allows you to merge multiple transcriptomes while maintaining source information.

### MultiQC

<details markdown="1">
<summary>Output files</summary>

- `multiqc/`
  - `multiqc_report.html`: a standalone HTML file that can be viewed in your web browser.
  - `multiqc_data/`: directory containing parsed statistics from the different tools used in the pipeline.
  - `multiqc_plots/`: directory containing static images from the report in various formats.

</details>

[MultiQC](http://multiqc.info) is a visualization tool that generates a single HTML report summarising all samples in your project. Most of the pipeline QC results are visualised in the report and further statistics are available in the report data directory.

Results generated by MultiQC collate pipeline QC from supported tools e.g. FastQC. The pipeline has special steps which also allow the software versions to be reported in the MultiQC output for future traceability. For more information about how to use MultiQC reports, see <http://multiqc.info>.

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
