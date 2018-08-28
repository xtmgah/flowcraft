if (params.asperaKey{{ param_id }}){
    if (file(params.asperaKey{{ param_id }}).exists()){
        IN_asperaKey_{{ pid }} = Channel.fromPath(params.asperaKey{{ param_id }})
    } else {
        IN_asperaKey_{{ pid }} = Channel.value("")
    }
} else {
    IN_asperaKey_{{ pid }} = Channel.value("")
}

process reads_download_{{ pid }} {

    {% include "post.txt" ignore missing %}

    tag { accession_id }
    publishDir "reads", pattern: "${accession_id}/*fq.gz"
    maxRetries 1

    input:
     set val(accession_id), val(name) from reads_download_in_1_0.splitText(){ it.trim() }.filter{ it != "" }.map{ it.split().length > 1 ? ["accession": it.split()[0], "name": it.split()[1]] : [it.split()[0], null] }
    each file(aspera_key) from IN_asperaKey_{{ pid }}

    output:
    set val({ "$name" != "null" ? "$name" : "$accession_id" }), file("${accession_id}/*fq.gz") optional true into {{ output_channel }}
    {% with task_name="reads_download", sample_id="accession_id" %}
    {%- include "compiler_channels.txt" ignore missing -%}
    {% endwith %}

    script:
    """
    {
        echo "${accession_id}" >> accession_file.txt
        echo "pass" > ".status"

        if [ -f $aspera_key ]; then
            asperaOpt="-a $aspera_key"
        else
            asperaOpt=""
        fi

        getSeqENA.py -l accession_file.txt \$asperaOpt -o ./ --SRAopt --downloadCramBam

        if [ $name != null ];
        then
            echo renaming pattern '${accession_id}' to '${name}' && cd ${accession_id} && rename "s/${accession_id}/${name}/" *.gz
        fi
    } || {
        # If exit code other than 0
        if [ \$? -eq 0 ]
        then
            echo "pass" > .status
        else
            echo "fail" > .status
            echo "Could not download accession $accession_id" > .fail
        fi
    }
    """

}

{{ forks }}
