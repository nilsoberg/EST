#!/bin/bash
set -e

TEST_RESULTS_DIR=$1

OUTPUT_DIR="$TEST_RESULTS_DIR/test_results_sequence_blast"

rm -rf $OUTPUT_DIR

python create_est_nextflow_params.py blast --output-dir $OUTPUT_DIR --efi-config smalldata/efi.config --fasta-db smalldata/databases/blastdb/combined.fasta --efi-db smalldata/databases/efi_db.sqlite
nextflow -C conf/docker.config run est.nf -params-file $OUTPUT_DIR/params.yml

python create_ssn_nextflow_params.py auto --filter-min-val 87 --ssn-name testssn --ssn-title test-ssn --est-output-dir $OUTPUT_DIR
# python create_ssn_nextflow_params.py manual --filter-min-val 87 --ssn-name name --ssn-title title --blast-parquet smalldata/results/1.out.parquet --fasta-file smalldata/results/all_sequences.fasta --output-dir $OUTPUT_DIR/ssn --efi-config smalldata/efi.config --efi-db smalldata/databases/efi_db.sqlite
nextflow -C conf/docker.config run ssn.nf -params-file $OUTPUT_DIR/ssn/params.yml