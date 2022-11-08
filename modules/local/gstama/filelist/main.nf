process GSTAMA_FILELIST {
    tag "$meta.id"
    label 'process_medium'

    conda (params.enable_conda ? "conda-forge::sed=4.7" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'ubuntu:20.04' }"

    input:
    tuple val(meta), path(bed)
    val cap
    val order

    output:
    tuple val(meta), path("*.tsv"), emit: tsv
    path "versions.yml"           , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    for i in *.bed
    do
        echo -e "\${i}\\t${cap}\\t${order}\\t\${i}" >> ${prefix}.tsv
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        echo: \$( echo --version | head -n1 | sed -e 's/echo (GNU coreutils) //')
    END_VERSIONS
    """
}
