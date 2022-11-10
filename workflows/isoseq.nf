/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowIsoseq.initialise(params, log)

// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.multiqc_config, params.fasta, params.primers ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
//ch_multiqc_config = [
//                        file("$projectDir/assets/multiqc_config.yml"           , checkIfExists: true),
//                        file("$projectDir/assets/nf-core-isoseq_logo_light.png", checkIfExists: true)
//                    ]
//ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK }                              from '../subworkflows/local/input_check'
include { SET_CHUNK_NUM_CHANNEL }                    from '../subworkflows/local/set_chunk_num_channel'
include { SET_VALUE_CHANNEL as SET_FASTA_CHANNEL }   from '../subworkflows/local/set_value_channel'
include { SET_VALUE_CHANNEL as SET_GTF_CHANNEL }     from '../subworkflows/local/set_value_channel'
include { SET_VALUE_CHANNEL as SET_PRIMERS_CHANNEL } from '../subworkflows/local/set_value_channel'

//
// MODULE: Local to the pipeline
//
include { GSTAMA_FILELIST } from '../modules/local/gstama/filelist/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { PBCCS }                       from '../modules/nf-core/pbccs/main'
include { LIMA }                        from '../modules/nf-core/lima/main'
include { ISOSEQ3_REFINE }              from '../modules/nf-core/isoseq3/refine/main'
include { BAMTOOLS_CONVERT }            from '../modules/nf-core/bamtools/convert/main'
include { GSTAMA_POLYACLEANUP }         from '../modules/nf-core/gstama/polyacleanup/main'
include { GUNZIP }                      from '../modules/nf-core/gunzip/main'
include { MINIMAP2_ALIGN }              from '../modules/nf-core/minimap2/align/main'
include { ULTRA_INDEX }                 from '../modules/nf-core/ultra/index/main'
include { ULTRA_ALIGN }                 from '../modules/nf-core/ultra/align/main'
include { GSTAMA_COLLAPSE }             from '../modules/nf-core/gstama/collapse/main'
include { GSTAMA_MERGE }                from '../modules/nf-core/gstama/merge/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main' addParams( options: [publish_files : ['_versions.yml':'']] )
include { MULTIQC }                     from '../modules/nf-core/multiqc/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow ISOSEQ {
    //
    // SET UP VERSIONS CHANNELS
    //
    ch_versions = Channel.empty()


    //
    // START PIPELINE
    //
    INPUT_CHECK(params.input, params.chunk) // Check samplesheet input for PBCCS module
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    SET_CHUNK_NUM_CHANNEL(params.input, params.chunk) // Prepare channels for:
    SET_FASTA_CHANNEL(params.fasta)                   // - genome fasta
    SET_GTF_CHANNEL(params.gtf)                       // - primers fasta
    SET_PRIMERS_CHANNEL(params.primers)               // - genome gtf
                                                      // - PBCCS parallelization

    PBCCS(INPUT_CHECK.out.reads, SET_CHUNK_NUM_CHANNEL.out.chunk_num, params.chunk) // Generate CCS from raw reads
    PBCCS.out.bam // Update meta: update id (+chunkX) and store former id
    .map {
        def chk       = (it[1] =~ /.*\.(chunk\d+)\.bam/)[ 0 ][ 1 ]
        def id_former = it[0].id
        def id_new    = it[0].id + "." + chk
        return [ [id:id_new, id_former:id_former, single_end:true], it[1] ]
    }
    .set { ch_pbccs_bam_updated }

    LIMA(ch_pbccs_bam_updated, SET_PRIMERS_CHANNEL.out.data)   // Remove primers from CCS
    ISOSEQ3_REFINE(LIMA.out.bam, SET_PRIMERS_CHANNEL.out.data) // Discard CCS without polyA tails, remove it from the other
    BAMTOOLS_CONVERT(ISOSEQ3_REFINE.out.bam)                   // Convert bam to fasta
    GSTAMA_POLYACLEANUP(BAMTOOLS_CONVERT.out.data)             // Clean polyA tails from reads

    // Align FLNCs: User can choose between minimap2 and uLTRA aligners
    if (params.aligner == "ultra") {
        ULTRA_INDEX(SET_FASTA_CHANNEL.out.data, SET_GTF_CHANNEL.out.data)                 // Index GTF file before alignment
        GUNZIP(GSTAMA_POLYACLEANUP.out.fasta)                                             // uncompress fastas (gz not supported by uLTRA)
        ULTRA_ALIGN(GUNZIP.out.gunzip, SET_FASTA_CHANNEL.out.data, ULTRA_INDEX.out.index) // Align read against genome
        GSTAMA_COLLAPSE(ULTRA_ALIGN.out.bam, SET_FASTA_CHANNEL.out.data)                  // Clean gene models
    }
    else if (params.aligner == "minimap2") {
        MINIMAP2_ALIGN(                    // Align read against genome
            GSTAMA_POLYACLEANUP.out.fasta,
            SET_FASTA_CHANNEL.out.data,
            Channel.value('bam'),
            Channel.value(false),
            Channel.value(false))
        GSTAMA_COLLAPSE(MINIMAP2_ALIGN.out.bam, SET_FASTA_CHANNEL.out.data) // Clean gene models
    }

    GSTAMA_COLLAPSE.out.bed // replace id with the former sample id and group files by sample
        .map { [ [id:it[0].id_former], it[1] ] }
        .groupTuple()
        .set { ch_tcollapse }

    if (params.capped == true) {
        GSTAMA_FILELIST( // Generate the filelist file needed by TAMA merge
        ch_tcollapse,
        Channel.value("capped"),
        Channel.value("1,1,1"))
    }
    else {
        GSTAMA_FILELIST( // Generate the filelist file needed by TAMA merge
        ch_tcollapse,
        Channel.value("no_cap"),
        Channel.value("1,1,1"))
    }

    ch_tcollapse // Synchronized bed files produced by TAMA collapse with file list file generated by GSTAMA_FILELIST
        .join( GSTAMA_FILELIST.out.tsv )
        .set { ch_tmerge_in }

    GSTAMA_MERGE(ch_tmerge_in.map { [ it[0], it[1] ] }, ch_tmerge_in.map { it[2] }) // Merge all bed files from one sample into a uniq bed file


    //
    // MODULE: Pipeline reporting
    //
    ch_versions = ch_versions.mix(PBCCS.out.versions)
    ch_versions = ch_versions.mix(LIMA.out.versions)
    ch_versions = ch_versions.mix(ISOSEQ3_REFINE.out.versions)
    ch_versions = ch_versions.mix(BAMTOOLS_CONVERT.out.versions)
    ch_versions = ch_versions.mix(GSTAMA_COLLAPSE.out.versions)
    ch_versions = ch_versions.mix(GSTAMA_MERGE.out.versions)
    ch_versions = ch_versions.mix(GSTAMA_POLYACLEANUP.out.versions)

    if (params.aligner == "ultra") {
        ch_versions = ch_versions.mix(ULTRA_INDEX.out.versions)
        ch_versions = ch_versions.mix(ULTRA_ALIGN.out.versions)
    }
    else if (params.aligner == "minimap2") {
        ch_versions = ch_versions.mix(MINIMAP2_ALIGN.out.versions)
    }


    //
    // MODULE: CUSTOM_DUMPSOFTWAREVERSIONS
    //
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )


    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowIsoseq.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowIsoseq.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(PBCCS.out.report_json.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(LIMA.out.summary.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(LIMA.out.counts.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.collect().ifEmpty([]),
        ch_multiqc_custom_config.collect().ifEmpty([]),
        ch_multiqc_logo.collect().ifEmpty([])
//       ch_multiqc_files.collect(),
//       ch_multiqc_config,
//       [],
//       []
    )
    multiqc_report = MULTIQC.out.report.toList()
    ch_versions    = ch_versions.mix(MULTIQC.out.versions)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.adaptivecard(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
