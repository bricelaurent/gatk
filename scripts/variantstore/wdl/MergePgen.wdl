version 1.0

workflow MergePgenWorkflow {
    input {
        Array[File] pgen_files
        Array[File] pvar_files
        Array[File] psam_files
        String plink_docker
        String output_file_base_name
        Int merge_disk_size
        Int? threads
    }

    call MergePgen {
        input:
            pgen_files = pgen_files,
            pvar_files = pvar_files,
            psam_files = psam_files,
            plink_docker = plink_docker,
            output_file_base_name = output_file_base_name,
            disk_in_gb = merge_disk_size,
            threads = threads
    }

    output {
        File pgen_file = MergePgen.pgen_file
        File pvar_file = MergePgen.pvar_file
        File psam_file = MergePgen.psam_file
    }
}

task MergePgen {
    input {
        Array[File] pgen_files
        Array[File] pvar_files
        Array[File] psam_files
        String plink_docker
        String output_file_base_name
        Int disk_in_gb
        Int threads = 1
    }

    parameter_meta {
        pgen_files: {
            localization_optional: true
        }
        pvar_files: {
            localization_optional: true
        }
        psam_files: {
            localization_optional: true
        }
    }

    Int cpu = threads + 1

    command <<<
        set -e

        # Download files using gsutil
        mkdir pgen_dir

        PGEN_ARRAY=(~{sep=" " pgen_files})
        printf "%s\n" "${PGEN_ARRAY[@]}" | gsutil -m cp -I pgen_dir

        PSAM_ARRAY=(~{sep=" " psam_files})
        printf "%s\n" "${PSAM_ARRAY[@]}" | gsutil -m cp -I pgen_dir

        PVAR_ARRAY=(~{sep=" " pvar_files})
        printf "%s\n" "${PVAR_ARRAY[@]}" | gsutil -m cp -I pgen_dir

        # Create a file with a list of all the pgen basenames for merging
        touch mergelist.txt
        count=0
        for pgen in pgen_dir/*.pgen
        do
            if [ -s ${pgen} ]
            then
                count=$((count+1))
                echo -e "${pgen%.pgen}" >> mergelist.txt
            fi
        done

        case $count in
        0)
            echo "No pgen files so creating empty ones"
            touch ~{output_file_base_name}.pgen
            touch ~{output_file_base_name}.pvar
            touch ~{output_file_base_name}.psam
            ;;
        1)
            echo "Only one pgen file so renaming the files for output"
            pgen_basename=$(cat mergelist.txt | xargs)
            mv ${pgen_basename}.pgen ~{output_file_base_name}.pgen
            mv ${pgen_basename}.psam ~{output_file_base_name}.psam
            mv ${pgen_basename}.pvar ~{output_file_base_name}.pvar
            ;;
        *)
            echo "${count} pgen files, merging"
            plink2 --pmerge-list mergelist.txt pfile-vzs --threads ~{threads} --out ~{output_file_base_name}
            ;;
        esac

    >>>

    output {
        File pgen_file = "${output_file_base_name}.pgen"
        File pvar_file = "${output_file_base_name}.pvar"
        File psam_file = "${output_file_base_name}.psam"
    }

    runtime {
        docker: "${plink_docker}"
        memory: "12 GB"
        disks: "local-disk ${disk_in_gb} HDD"
        bootDiskSizeGb: 15
        cpu: "${cpu}"
    }
}
