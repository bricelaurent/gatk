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

    Int file_count = length(actual)

    Int disk_in_gb = 2 * ceil(10 + size(actual, "GB") + size(expected, "GB"))

    command <<<
        set -euxo pipefail

        sort_by_basename() {
            local unsorted="$1"
            # Make a map of basenames to filenames
            declare -A basename_map
            while read -r filename
            do
                file_basename=$(basename "$filename")
                basename_map["$file_basename"]="$filename"
            done <"$unsorted"
            # Sort the basenames
            for basename in "${!basename_map[@]}"
            do 
                echo "$basename"; 
            done | sort > "sorted.txt"
            # Write the filenames sorted by basename to a file
            local sorted_filename="$2"
            while read -r file_basename
            do
                echo "$basename_map[$file_basename]" >> "$sorted_filename"
            done <"sorted.txt"
        }

        # Write the vcf lists to files and sort them by vcf basename so the vcfs match up correctly
        unsorted_actual=~{write_lines(actual)}
        sort_by_basename "$unsorted_actual" "sorted_actual.txt"
        unsorted_expected=~{write_lines(expected)}
        sort_by_basename "$unsorted_expected" "sorted_expected.txt"

        # Generate diff files for each pair of files
        for ((i = 1; i <= ~{file_count}; i++))
        do
            local actual_file=$(sed -n "${i}p" "sorted_actual.txt")
            local expected_file=$(sed -n "${i}p" "sorted_expected.txt")
            echo "actual: ${actual_file} , expected ${expected_file}"
            # Generate the diff file
            output_file="$(basename ${actual_file}).diff"
            java -jar -Xmx5g /comparator/pgen_vcf_comparator.jar "${actual_file}" "${expected_file}" > "$output_file"
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