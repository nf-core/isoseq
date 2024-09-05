# nf-core/isoseq: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v2.0.0 - Sapphire Duck [05/09/2024]

New entrypoint option to skip isoseq pre-processing.
Update the pipeline to nf-core 2.14.1.
Update modules.
nf-validation version pinned [PR25](https://github.com/nf-core/isoseq/issues/25)
Upgrade from isoseq3 to isoseq (version 4) Fix segmentation fault [PR27](https://github.com/nf-core/isoseq/issues/27)
Add alternative entrypoint [PR10](https://github.com/nf-core/isoseq/issues/10)

### `Added`

A new entreypoint system has been implemented to allow the user where to start the analysis.
The `isoseq` entrypoint runs the full pipeline.
The `map` entrypoint runs the pipeline from the mapping step.
This new `entreypoint` option make possible to use the isoseq pipeline for analysis PacBio data when subreads are not provided, or for users who want to benefit from the mapping + TAMA analysis for their Nanopore data.

### `Fixed`

- Update modules to their nf-test version (bamtools/convert, custom/dumpsoftwareversions, gnu/sort, gstama/collapse/ gstama/merge, gstama/polyacleanup, gunzip, isoseq/refine, lima, minimap2/align, pbccs,ultra/align, ultra/index)
- Since isoseq3 switch to version 4, it has been rename isoseq

  | Tool             | Previous version | New version |
  | ---------------- | ---------------- | ----------- |
  | bamtools/convert | 2.5.2            | 2.5.2       |
  | isoseq           | 3.8.2            | 4.0.0       |
  | lima             | 2.7.1            | 2.9.0       |
  | minimap2/align   | 2.24             | 2.28        |
  | gnu/sort         | 8.25             | 9.3         |
  | multiqc          | 1.21             | 1.24.1      |

### `Dependencies`

### `Deprecated`

## v1.1.5 - Byzantium Buzzard [02/08/2023]

Update the pipeline to nf-core 2.9.

### `Added`

### `Fixed`

- Add gnu/sort to sort annotation before uLTRA index
- Update citations
- Add background to pipeline png
  | Tool | Previous version | New version |
  | ----------------------- | ---------------- | ----------- |
  | isoseq3 | 3.8.1 | 3.8.2 |
  | lima | 2.6.0 | 2.7.1 |
  | bamtools/convert | 2.5.1 | 2.5.2 |
  | gstama/merge | 1.0.2 | 1.0.3 |
  | uLTRA/index | 0.0.4.2 | 0.1 |
  | uLTRA/align | 0.0.4.2 | 0.1 |
  | samtools | 1.17 | 1.17 |
  | gnu/sort | ---- | 8.25 |

### `Dependencies`

### `Deprecated`

## v1.1.4 - Teal Albatross [13/03/2023]

### `Added`

### `Fixed`

- Update minimap2 path test: Don't set gtf option. It is not expected to be used with minimap2 is chosen.
- FIX: Don't prepare gtf channel when minimap2 is chosen.

### `Dependencies`

### `Deprecated`

## v1.1.3 - Blue Grouse [06/03/2023]

### `Added`

### `Fixed`

- Fix pipeline image path
- params.input invalid type if pipeline is run with local file in samplesheet (was working with URL)

### `Dependencies`

### `Deprecated`

## v1.1.2 - Gray Eagle [11/01/2023]

### `Added`

- Fix [issue #17](https://github.com/ksahlin/ultra/issues/17). Thanks to [Husen M. Umer](https://github.com/husensofteng).
- Zenodo DOI
- Update to template v2.7.2

### `Fixed`

- Remove hard coded capped option for GSTAMA_FILELIST step. Now follow user choice. Thanks to [Mazdak Salavati](https://github.com/MazdaX).

### `Dependencies`

| Tool                 | Previous version | New version |
| -------------------- | ---------------- | ----------- |
| isoseq3              | 3.4.0            | 3.8.1       |
| lima                 | 2.2.0            | 2.6.0       |
| minimap2             | 2.21             | 2.24        |
| samtools             | 1.12             | 1.14        |
| multiqc              | 1.13             | 1.14        |
| pbccs                | 6.2.0            | 6.4.0       |
| ultra_bioinformatics | 0.0.4            | 0.0.4.2     |
| samtools             | 1.15.1           | 1.16.1      |

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
