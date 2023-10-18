version 1.0

workflow CompareFilesWorkflow {
    input{
        Array[File] actual
        Array[File] expected
    }

    call CompareFiles {
        input:
            actual = actual,
            expected = expected
    }

    output {
        Array[File] diffs = CompareFiles.diffs
    }
}

task CompareFiles {

    input{
        Array[File] actual
        Array[File] expected
    }

    Int disk_in_gb = 2 * ceil(10 + size(actual, "GB") + size(expected, "GB"))

    command <<<
        set -e

        UNSORTED_ACTUAL_ARRAY=(~{sep=" " actual})
        ACTUAL_ARRAY=($(printf "%s\n" "${UNSORTED_ACTUAL_ARRAY[@]}" | sort))
        UNSORTED_EXPECTED_ARRAY=(~{sep=" " expected})
        EXPECTED_ARRAY=($(printf "%s\n" "${UNSORTED_EXPECTED_ARRAY[@]}" | sort))
        touch sizes.txt
        for i in "${!ACTUAL_ARRAY[@]}"
        do
            echo "expected: ${EXPECTED_ARRAY[$i]} , actual: ${ACTUAL_ARRAY[$i]}"
            # Generate the diff file
            output_file="$(basename ${ACTUAL_ARRAY[$i]}).diff"
            java -jar -Xmx5g /comparator/pgen_vcf_comparator.jar "${ACTUAL_ARRAY[$i]}" "${EXPECTED_ARRAY[$i]}" > "$output_file"
            # If the diff file is empty, delete it
            if ! [ -s "$output_file" ]
            then
                rm "$output_file"
            fi
        done
    >>>

    output {
        Array[File] diffs = glob("*.diff")
    }

    runtime {
        docker: "us.gcr.io/broad-dsde-methods/klydon/pgen_vcf_comparator:test"
        memory: "6 GB"
        disks: "local-disk ${disk_in_gb} HDD"
        preemptible: 3
        cpu: 1
    }
}