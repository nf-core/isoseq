//
// Takes fasta from LIMA and ISOSEQ REFINE inputs and splits their generated fastas
//

workflow CHUNKER {
    take:
    ch_input_fastas // Channel: [ meta[id, start_from ], fasta ]
    chunk           // value: integer (number of chunk to create)
    in_decompress   // value: true or false
    out_compress    // value: true or false

    main:
    // ch_input_fastas.view { meta, fa -> println("CHUNKER:ch_input_fastas: $meta | $fa") }

    ch_input_fastas
        .branch { meta, _fasta ->
            chunk   :   meta.id =~ /chunk/
            to_chunk: !(meta.id =~ /chunk/)
        }
        .set { ch_input_fastas_branched }

    // ch_input_fastas_branched.chunk.view      { meta, fa -> println("CHUNKER:ch_input_fastas_branched.chunk: $meta | $fa") }
    // ch_input_fastas_branched.to_chunk.view { meta, fa -> println("CHUNKER:ch_input_fastas_branched.to_chunk: $meta | $fa") }

    ch_input_fastas_branched.to_chunk
        .splitFasta(
            by: chunk,
            decompress: in_decompress,
            file: "chunk",
            compress: out_compress
        )
        .map { meta, file ->
            def chk = (file =~ /(chunk\.\d+)(?:\.gz)?$/)[ 0 ][ 1 ]
            def id_former = meta.id
            def id_new    = meta.id + "." + chk
            [ [ id:id_new, id_former:id_former, start_from:meta.start_from ] , file ]
        }
        .concat(ch_input_fastas_branched.chunk)
        .set { fastas }

    emit:
    fastas
}
