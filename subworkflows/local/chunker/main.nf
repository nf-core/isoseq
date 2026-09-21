//
// Takes fasta from LIMA and ISOSEQ REFINE inputs and splits their generated fastas
//

workflow CHUNKER {
    take:
    ch_input_fastas // Channel: [ meta[id, start_from ], fasta ]
    chunk           // value: integer (number of chunk to create)
    out_compress    // value: true or false

    main:
    // ch_input_fastas.view { meta, fa -> println("CHUNKER:ch_input_fastas: $meta | $fa") }

    // Fastas already split (by PBCCS or a previous CHUNKER) carry an `id_former` key
    ch_input_fastas
        .branch { meta, _fasta ->
            chunk   :  meta.containsKey('id_former')
            to_chunk: !meta.containsKey('id_former')
        }
        .set { ch_input_fastas_branched }

    // ch_input_fastas_branched.chunk.view      { meta, fa -> println("CHUNKER:ch_input_fastas_branched.chunk: $meta | $fa") }
    // ch_input_fastas_branched.to_chunk.view { meta, fa -> println("CHUNKER:ch_input_fastas_branched.to_chunk: $meta | $fa") }

    ch_input_fastas_branched.to_chunk
        .splitFasta( // gzipped inputs are detected from the .gz extension
            by: chunk,
            file: "chunk.fa", // chunk.<N>.fa or chunk.<N>.fa.gz
            compress: out_compress
        )
        .map { meta, file ->
            def chk = (file =~ /(chunk\.\d+)\.fa(?:\.gz)?$/)[ 0 ][ 1 ]
            def id_former = meta.id
            def id_new    = meta.id + "." + chk
            [ [ id:id_new, id_former:id_former, start_from:meta.start_from ] , file ]
        }
        .concat(ch_input_fastas_branched.chunk)
        .set { fastas }

    emit:
    fastas
}
