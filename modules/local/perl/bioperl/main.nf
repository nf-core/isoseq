process PERL_BIOPERL {
    tag "$meta.id"
    label 'process_low'

    conda (params.enable_conda ? "bioconda::perl-bioperl=1.7.2" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/perl-bioperl:1.7.2--pl526_11' :
        'quay.io/biocontainers/perl-bioperl:1.7.2--pl526_11' }"

    input:
    tuple val(meta), path(file)

    output:
    tuple val(meta), path("${task.ext.prefix}"), emit: out
    path "versions.yml"                        , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    perl \\
        $args \\
        $file > $prefix

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        perl: \$( perl --version 2>&1|perl -ne 'print \$1 if (/(v\\d+\\.\\d+\\.\\d+)/)' )
    END_VERSIONS
    """
}
