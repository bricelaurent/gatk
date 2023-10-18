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

        sort_by_basename() {
            local unsorted=("$@")
            # Make a map of basenames to filenames
            declare -A basename_map
            for filename in "${unsorted[@]}"
            do
                file_basename=$(basename "$filename")
                basename_map["$file_basename"]="$filename"
            done
            # Sort the basenames
            local sorted_basenames=($(for basename in "${!basename_map[@]}"; do echo "$basename"; done | sort))
            # Build an array of the filenames sorted by basename
            local sorted_filenames=()
            for file_basename in "${sorted_basenames[@]}"
            do
                sorted_filenames+=("$basename_map[$file_basename]")
            done

            echo "${sorted_filenames[@]}"
        }

        UNSORTED_ACTUAL_ARRAY=(~{sep=" " actual})
        ACTUAL_ARRAY=($(sort_by_basename "${UNSORTED_ACTUAL_ARRAY[@]}"))
        UNSORTED_EXPECTED_ARRAY=(~{sep=" " expected})
        EXPECTED_ARRAY=($(sort_by_basename "${UNSORTED_EXPECTED_ARRAY[@]}"))
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