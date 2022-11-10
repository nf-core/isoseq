# nf-core/isoseq: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.1.2 - Gray Eagle [10/11/2022]

### `Added`

- Update module pbccs (v6.2.0)
- Update module isoseq refine (v3.4.0)
- Update module lima (v2.2.0)
- Update module uLTRA (v0.0.4.2). Fix [issue #17](https://github.com/ksahlin/ultra/issues/17). Thanks to [Husen M. Umer](https://github.com/husensofteng).
- Zenodo DOI

### `Fixed`

- Remove hard coded capped option for GSTAMA_FILELIST step. Now follow user choice. Thanks to [Mazdak Salavati](https://github.com/MazdaX).

### `Dependencies`

### `Deprecated`

## v1.1.1 - White Hawk [26/09/2022]

Update the pipeline to nf-core 2.5.1, update modules, and fix documentation.

### `Added`

### `Fixed`

- Documentation: Correct aligner option documentation

### `Dependencies`

- Update `samplesheet_check` module
- Update `dumpsoftwareversion` module
- Update `MultiQC` module

### `Deprecated`

## v1.1.0 - Black Crow [12/07/2022]

Improves computation time.
Split `uLTRA pipeline` into two processes, `uLTRA index` and `uLTRA align`. `GTF` index is computed once and not `chunk` times.
`uLTRA align` sort and convert `sam` output into `bam` files. Aligned reads are already sorted by `minimap2` module. Therefore, `samtools sort` module is not needed anymore and has been removed.
The `bioperl` module objective was to deal with [spurious alignments produced by uLTRA if a malformed GTF is used](https://github.com/ksahlin/ultra/issues/11). Removing it will stop the pipeline in case of malformed `GTF`.
Module resource requirements have been revised for four modules (`gstama/merge`, `isoseq3/refine`, `lima`, `ultra/align`) to reduce requested resources.
AWS runs with shows better run time and CPU/RAM usage ([Results](docs/images/Isoseq_pipeline_v1.0.0_v1.1.0.png)).

### `Added`

- Add `uLTRA index` and `uLTRA align` to replace `uLTRA pipeline` [PR 1830](https://github.com/nf-core/modules/pull/1830)
- Module resources adjustments: `gstama/merge`, `isoseq3/refine`, `lima`, `ultra/align` [PR1858](https://github.com/nf-core/modules/pull/1858), `gunzip`, `MultiQC`

### `Fixed`

### `Dependencies`

### `Deprecated`

- Remove `uLTRA pipeline`
- Remove `samtools sort` module
- Remove `bioperl` module

## v1.0.0 - Silver Swan [28/06/2022]

Initial release of nf-core/isoseq, created with the [nf-core](https://nf-co.re/) template.

### `Added`

### `Fixed`

### `Dependencies`

### `Deprecated`
