version 1.0

import "GvsExtractCallsetPgen.wdl" as Extract
import "MergePgenHierarchical.wdl" as Merge

workflow GvsExtractCallsetMerged {

    input {
        Boolean go = true
        String dataset_name
        String project_id
        String call_set_identifier

        # Chromosome code corresponding to the set of contig names used by plink that matches those used by the
        # reference
        String pgen_chromosome_code = "chrM"
        # Max number of alt alleles a site can have. If a site exceeds this number, it will not be written
        Int max_alt_alleles = 254
        # If true, does not throw an exception for samples@sites with unsupported ploidy (codes it as missing instead)
        Boolean lenient_ploidy_validation = false

        String cohort_project_id = project_id
        String cohort_dataset_name = dataset_name
        Boolean do_not_filter_override = false
        Boolean control_samples = false
        String extract_table_prefix
        String filter_set_name
        String query_project = project_id
        # This is optional now since the workflow will choose an appropriate value below if this is unspecified.
        Int? scatter_count
        Boolean zero_pad_output_pgen_filenames = true

        # set to "NONE" if all the reference data was loaded into GVS in GvsImportGenomes
        String drop_state = "NONE"

        File interval_list = "gs://gcp-public-data--broad-references/hg38/v0/wgs_calling_regions.hg38.noCentromeres.noTelomeres.interval_list"
        Boolean use_interval_weights = true
        File interval_weights_bed = "gs://broad-public-datasets/gvs/weights/gvs_vet_weights_1kb.bed"

        File? gatk_override
        String? extract_docker_override

        String output_file_base_name = filter_set_name

        Int? extract_maxretries_override
        Int? extract_preemptible_override
        String? output_gcs_dir
        String? split_intervals_extra_args
        Int? split_intervals_disk_size_override
        Int? split_intervals_mem_override
        Float x_bed_weight_scaling = 4
        Float y_bed_weight_scaling = 4
        Boolean write_cost_to_db = true

        # Merge
        String plink_docker
    }

    call Extract.GvsExtractCallset {
        input:
            go = go,
            dataset_name = dataset_name,
            project_id = project_id,
            call_set_identifier = call_set_identifier,
            pgen_chromosome_code = pgen_chromosome_code,
            max_alt_alleles = max_alt_alleles,
            lenient_ploidy_validation = lenient_ploidy_validation,
            cohort_project_id = cohort_project_id,
            cohort_dataset_name = cohort_dataset_name,
            do_not_filter_override = do_not_filter_override,
            control_samples = control_samples,
            extract_table_prefix = extract_table_prefix,
            filter_set_name = filter_set_name,
            query_project = query_project,
            scatter_count = scatter_count,
            zero_pad_output_pgen_filenames = zero_pad_output_pgen_filenames,
            drop_state = drop_state,
            interval_list = interval_list,
            use_interval_weights = use_interval_weights,
            interval_weights_bed = interval_weights_bed,
            gatk_override = gatk_override,
            output_file_base_name = output_file_base_name,
            extract_maxretries_override = extract_maxretries_override,
            extract_preemptible_override = extract_preemptible_override,
            output_gcs_dir = output_gcs_dir,
            split_intervals_extra_args = split_intervals_extra_args,
            split_intervals_disk_size_override = split_intervals_disk_size_override,
            split_intervals_mem_override = split_intervals_mem_override,
            x_bed_weight_scaling = x_bed_weight_scaling,
            y_bed_weight_scaling = y_bed_weight_scaling,
            write_cost_to_db = write_cost_to_db,
            extract_docker_override = extract_docker_override
    }

    call Merge.MakeFileLists {
        input:
            pgen_files = GvsExtractCallset.output_pgens,
            pvar_files = GvsExtractCallset.output_pvars,
            psam_files = GvsExtractCallset.output_psams
    }

    call Merge.MergePgenWorkflow {
        input:
            pgen_file_list = MakeFileLists.pgen_list,
            pvar_file_list = MakeFileLists.pvar_list,
            psam_file_list = MakeFileLists.psam_list,
            plink_docker = plink_docker,
            output_file_base_name = output_file_base_name,
            merge_disk_size = 1024,
            split_count = ceil(length(GvsExtractCallset.output_pgens)/10),
            zero_padded_prefix = zero_pad_output_pgen_filenames
    }

    output {
        File merged_pgen = MergePgenWorkflow.pgen_file
        File merged_pvar = MergePgenWorkflow.pvar_file
        File merged_psam = MergePgenWorkflow.psam_file
        Array[File] output_pgens = GvsExtractCallset.output_pgens
        Array[File] output_pvars = GvsExtractCallset.output_pvars
        Array[File] output_psams = GvsExtractCallset.output_psams
        Array[File] output_pgen_interval_files = GvsExtractCallset.output_pgen_interval_files
        Float total_pgens_size_mb = GvsExtractCallset.total_pgens_size_mb
        File manifest = GvsExtractCallset.manifest
        File? sample_name_list = GvsExtractCallset.sample_name_list
    }

}