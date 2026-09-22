//
// Count number of samples in sampleSheet and create channel
//

workflow SET_CHUNK_NUM_CHANNEL {
    take:
    samplesheet // file: /path/to/samplesheet.csv
    chunk       // value: integer (number of chunk to create)

    main:
    int n_samples = file(samplesheet).readLines().size() - 1

    channel // Prepare the pbccs chunk_num channel
        .from((1..(chunk as int)).step(1).toList()*n_samples)
        .set { chunk_num }

    emit:
    chunk_num
}
