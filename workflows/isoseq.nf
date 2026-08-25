/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_isoseq_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { SET_CHUNK_NUM_CHANNEL                    } from '../subworkflows/local/set_chunk_num_channel/main'
include { SET_VALUE_CHANNEL as SET_FASTA_CHANNEL   } from '../subworkflows/local/set_value_channel/main'
include { SET_VALUE_CHANNEL as SET_GTF_CHANNEL     } from '../subworkflows/local/set_value_channel/main'
include { SET_VALUE_CHANNEL as SET_PRIMERS_CHANNEL } from '../subworkflows/local/set_value_channel/main'
include { CHUNKER as CHUNKER_BAMTOOLS_OUT          } from '../subworkflows/local/chunker/main'
include { CHUNKER as CHUNKER_INPUT_FASTAS          } from '../subworkflows/local/chunker/main'

//
// MODULE: Local to the pipeline
//
include { GSTAMA_FILELIST }                         from '../modules/local/gstama/filelist/main'
include { GSTAMA_FILELIST as GSTAMA_FILELIST_ALL }  from '../modules/local/gstama/filelist/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { PBCCS }                               from '../modules/nf-core/pbccs/main'
include { LIMA }                                from '../modules/nf-core/lima/main'
include { ISOSEQ_REFINE }                       from '../modules/nf-core/isoseq/refine/main'
include { BAMTOOLS_CONVERT }                    from '../modules/nf-core/bamtools/convert/main'
include { GSTAMA_POLYACLEANUP }                 from '../modules/nf-core/gstama/polyacleanup/main'
include { GUNZIP }                              from '../modules/nf-core/gunzip/main'
include { MINIMAP2_ALIGN }                      from '../modules/nf-core/minimap2/align/main'
include { GNU_SORT }                            from '../modules/nf-core/gnu/sort/main'
include { ULTRA_INDEX }                         from '../modules/nf-core/ultra/index/main'
include { ULTRA_ALIGN }                         from '../modules/nf-core/ultra/align/main'
include { GSTAMA_COLLAPSE }                     from '../modules/nf-core/gstama/collapse/main'
include { GSTAMA_MERGE }                        from '../modules/nf-core/gstama/merge/main'
include { GSTAMA_MERGE as GSTAMA_MERGE_ALL }    from '../modules/nf-core/gstama/merge/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow ISOSEQ {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    multiqc_config
    multiqc_logo
    multiqc_methods_description
    outdir

    main:

    // Set version and multiqc channels
    ch_versions      = channel.empty()
    ch_multiqc_files = channel.empty()

    // Value channels initialization
    SET_FASTA_CHANNEL(params.fasta)     // genome fasta
    ch_primers = channel.empty()        // primers fasta
    if (params.primers) {
        SET_PRIMERS_CHANNEL(params.primers) // primers fasta
        ch_primers = SET_PRIMERS_CHANNEL.out.data
    }
    if (params.aligner == "ultra") {
        SET_GTF_CHANNEL(params.gtf)     // genome gtf
    }

    // Dispatch inputs to redistribute them to their ad hoc starting point
    ch_samplesheet
        .branch { meta, _seq_data, _pbi ->
            ccs    : meta.start_from == "ccs"
            lima   : meta.start_from == "lima"
            refine : meta.start_from == "refine"
            mapping: meta.start_from == "mapping"
        }
        .set { ch_seq_data }
    // ch_seq_data.ccs.view    { it -> "BRANCH: ccs    : $it" }
    // ch_seq_data.lima.view   { it -> "BRANCH: lima   : $it" }
    // ch_seq_data.refine.view { it -> "BRANCH: refine : $it" }
    // ch_seq_data.mapping.view{ it -> "BRANCH: mapping: $it" }

    // PBCCS: prepare and run ccs
    SET_CHUNK_NUM_CHANNEL(params.input, params.chunk_ccs) // - PBCCS parallelization

    PBCCS(
        ch_seq_data.ccs,
        SET_CHUNK_NUM_CHANNEL.out.chunk_num,
        params.chunk_ccs) // Generate CCS from raw reads

    PBCCS.out.bam // Update meta: update id (+chunkX) and store former id
        .map { meta, file ->
            def chk       = (file =~ /.*\.(chunk\d+)\.bam/)[0][1]
            def id_former = meta.id
            def id_new    = meta.id + "." + chk
            return [ [id:id_new, id_former:id_former, single_end:true], file ]
        }
        .set { ch_pbccs_out_bam_updated }

    // LIMA: Add the samplesheet's LIMA inputs to the queue and run lima
    ch_pbccs_out_bam_updated
        .concat(ch_seq_data.lima.map { meta, bam, _pbi -> [ meta, bam ] })
        .set { ch_lima_input }
    // ch_lima_input.view { meta, bam -> println("ch_lima_input: $meta | $bam") }
    LIMA(ch_lima_input, ch_primers)  // Remove primers from CCS

    // LIMA: Add the samplesheet's refine inputs to the queue and run isoseq refine
    LIMA.out.bam
        .concat(ch_seq_data.refine.map { meta, bam, _pbi -> [ meta, bam ] })
        .set { ch_isoseq_refine_input }
    // ch_isoseq_refine_input.view { meta, bam -> println("ch_isoseq_refine_input: $meta | $bam") }
    ISOSEQ_REFINE(ch_isoseq_refine_input, ch_primers) // Discard CCS without polyA tails, remove it from the other

    // Convert bam files to fasta
    BAMTOOLS_CONVERT(ISOSEQ_REFINE.out.bam)        // Convert bam to fasta
    // BAMTOOLS_CONVERT.out.data.view { meta, fa -> println("BAMTOOLS_CONVERT.out.data: $meta | $fa") }

    // Split fastas into chunks
    CHUNKER_BAMTOOLS_OUT(BAMTOOLS_CONVERT.out.data, params.chunk_mapping, false, false) // false, false == no need to decompress input, don't compress output
    // CHUNKER_BAMTOOLS_OUT.out.fastas.view { meta, fa -> println("CHUNKER_BAMTOOLS_OUT.out.fasta: $meta | $fa") }

    // GSTAMA_POLYACLEANUP: Convert to fasta and run polyAcleanup
    GSTAMA_POLYACLEANUP(CHUNKER_BAMTOOLS_OUT.out.fastas) // Clean polyA tails from reads
    // GSTAMA_POLYACLEANUP.out.fasta.view { meta, fa -> println("GSTAMA_POLYACLEANUP.out.fasta: $meta | $fa") }

    // Split user fasta and add them the main channel
    CHUNKER_INPUT_FASTAS(ch_seq_data.mapping.map { meta, fasta, _pbi -> [ meta, fasta ] }, params.chunk_mapping, true, false)
    // CHUNKER_INPUT_FASTAS.out.fastas.view { meta, fa -> println("CHUNKER_INPUT_FASTAS.out.fasta: $meta | $fa") }

    // MAPPING: Split samplesheet's fasta files, add them to the queue and run mapping
    GSTAMA_POLYACLEANUP.out.fasta
        .concat(CHUNKER_INPUT_FASTAS.out.fastas)
        .set { ch_input_fastas }
    // ch_input_fastas.view { meta, fa -> println("ch_input_fastas.out.fasta: $meta | $fa") }

    // Align FLNCs: User can choose between minimap2 and uLTRA aligners
    if (params.aligner == "ultra") {
        GNU_SORT(SET_GTF_CHANNEL.out.data.map { it -> [ [id:'genome'], it, 'gtf' ] } ) // Sort GTF on sequence and start, uLTRA index fails with topological sort
        ULTRA_INDEX(                                                            // Index GTF file before alignment
            SET_FASTA_CHANNEL.out.data.map { it -> [ [id:'genome'], it ] },
            GNU_SORT.out.sorted)
        GUNZIP(ch_input_fastas)                                                 // uncompress fastas (gz not supported by uLTRA)

        // The ultra index channel must be the same size as the reads/GUNZIP channel.
        // join: gather all index files into one channel
        // combine: duplicates index tuples to match number of reads
        // map: remove read and its meta as we don't need them
        ch_ultra_index =
            ULTRA_INDEX.out.pickle
            .join(ULTRA_INDEX.out.database)
            .combine(GUNZIP.out.gunzip)
            .map { meta1, pickle, db, _meta2, _reads -> [ meta1, pickle, db ] }

        ULTRA_ALIGN(
            GUNZIP.out.gunzip,
            SET_FASTA_CHANNEL.out.data.map { it -> [ [id:'genome'], it ] },
            ch_ultra_index)                                                     // Align read against genome
        GSTAMA_COLLAPSE(ULTRA_ALIGN.out.bam, SET_FASTA_CHANNEL.out.data)        // Clean gene models
    }
    else if (params.aligner == "minimap2") {
        MINIMAP2_ALIGN(                    // Align read against genome
            ch_input_fastas,
            [ [id:'genome'], file(params.fasta) ],
            channel.value(true),
            channel.value("bai"),
            channel.value(false),
            channel.value(false))
        GSTAMA_COLLAPSE(MINIMAP2_ALIGN.out.bam, SET_FASTA_CHANNEL.out.data) // Clean gene models
    }

    GSTAMA_COLLAPSE.out.bed // replace id with the former sample id and group files by sample
        .map { meta, file ->
            def sample = meta.id_former.replaceAll(/_\d+/, '')
            [
                [ id:sample ],
                file
            ]
        }
        .groupTuple()
        .set { ch_tcollapse }

    // ch_tcollapse.view { meta, fa -> println("ch_tcollapse: $meta | $fa") }

    cap_value = params.capped == true ? channel.value("capped") : channel.value("no_cap")

    GSTAMA_FILELIST( // Generate the filelist file needed by TAMA merge
    ch_tcollapse,
    cap_value,
    channel.value("1,1,1"))

    ch_tcollapse // Synchronized bed files produced by TAMA collapse with file list file generated by GSTAMA_FILELIST
        .join( GSTAMA_FILELIST.out.tsv )
        .set { ch_tmerge_in }

    GSTAMA_MERGE(ch_tmerge_in.map { [ it[0], it[1] ] }, ch_tmerge_in.map { it[2] }) // Merge all bed files from one sample into a uniq bed file

    // Merge all bed files from all samples into a uniq bed file
    ( params.tama_merge_all ? GSTAMA_MERGE.out.bed : channel.empty() )
        .map { _meta, bed -> [ [ id: "all_samples" ], bed ] }
        .groupTuple()
        .filter { _meta, beds -> beds.size() > 1 } // Only merge if there are more than one bed file
        .set { ch_merge_all_filelist_input }

    GSTAMA_FILELIST_ALL(
        ch_merge_all_filelist_input,
        cap_value,
        channel.value("1,1,1")
    )

    ch_merge_all_filelist_input
        .join( GSTAMA_FILELIST_ALL.out.tsv )
        .set { ch_tmerge_all_in }

    GSTAMA_MERGE_ALL(
        ch_tmerge_all_in.map { meta, beds, _list -> [ meta, beds ] },
        ch_tmerge_all_in.map { _meta, _beds, list -> list }
    )

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'nf_core_'  +  'isoseq_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        )

    //
    // MODULE: MultiQC
    //
    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = multiqc_methods_description ?
        file(multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))

    ch_multiqc_files = ch_multiqc_files.mix(PBCCS.out.report_json.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(LIMA.out.summary.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(LIMA.out.counts.collect{it[1]}.ifEmpty([]))

    MULTIQC (
        ch_multiqc_files.flatten().collect().map { files ->
            [
                [ id: 'isoseq' ],
                files,
                multiqc_config
                    ? file(multiqc_config, checkIfExists: true)
                    : file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true),
                multiqc_logo ? file(multiqc_logo, checkIfExists: true) : [],
                [],
                [],
            ]
        }
    )

    emit:
    multiqc_report = MULTIQC.out.report.map { _meta, report -> [report] }.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
