#!/bin/bash

# Exit on any error
set -xe

run_indexing() {
  echo "Running Indexing using ${1} and params: ${2} $(date)"
  opensearch-benchmark run \
      --target-host=$1 \
      --kill-running-processes \
      --workload vectorsearch \
      --pipeline benchmark-only \
      --workload-params $2 \
      --test-procedure=no-train-test-index-only \
      --exclude-tasks "delete-target-index" \
      --client-options="timeout:1200,amazon_aws_log_in:client_option,aws_access_key_id:$3,aws_secret_access_key:$4,aws_session_token:$5,region:us-east-1,service:es"
  echo "Completed Indexing at $(date)"
}

run_force_merge() {
  echo "Running Force Merge using ${1} and params: ${2} $(date)"
  opensearch-benchmark run \
      --target-host=$1 \
      --kill-running-processes \
      --workload vectorsearch \
      --pipeline benchmark-only \
      --workload-params $2 \
      --test-procedure=force-merge-index \
      --client-options="timeout:1200,amazon_aws_log_in:client_option,aws_access_key_id:$3,aws_secret_access_key:$4,aws_session_token:$5,region:us-east-1,service:es"
  echo "Completed Force Merge at $(date)"
}

run_search() {
  echo "Running Search using ${1} and params: ${2} $(date)"
  opensearch-benchmark run \
      --target-host=$1 \
      --kill-running-processes \
      --workload vectorsearch \
      --pipeline benchmark-only \
      --workload-params $2 \
      --test-procedure=search-only \
      --client-options="timeout:1200,amazon_aws_log_in:client_option,aws_access_key_id:$3,aws_secret_access_key:$4,aws_session_token:$5,region:us-east-1,service:es"
  echo "Completed Search at $(date)"
}

knn_stats() {
  echo "KNN Stats at $(date)"
  awscurl --service es --region us-east-1 "$1/_plugins/_knn/stats?pretty"
  echo ""
}

# Function to display usage
usage() {
    cat << EOF
Usage: $(basename $0) <endpoint> <params-file> <aws_access_key_id> <aws_secret_access_key> <aws_session_token>

Arguments:
    endpoint              OpenSearch cluster endpoint
    params-file           Parameters file for the workload
    aws_access_key_id     AWS Access Key ID
    aws_secret_access_key AWS Secret Access Key
    aws_session_token     AWS Session Token

Example:
    $(basename $0) https://aws.endpoint.com params.json AKIAIOSFODNN7EXAMPLE wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY IQoJb3JpZ2luX2VjEPT//////////wEaCXVzLWVhc3QtMSJHMEUCIQDTGfnh
EOF
    exit 1
}

# Main execution
if [[ $# -ne 5 ]]; then
    usage
fi

endpoint="$1"
params_file="$2"
aws_access_key_id="$3"
aws_secret_access_key="$4"
aws_session_token="$5"

echo "Starting full benchmark suite at $(date)"
knn_stats $endpoint
run_indexing $endpoint $params_file $aws_access_key_id $aws_secret_access_key $aws_session_token
knn_stats $endpoint
run_force_merge $endpoint $params_file $aws_access_key_id $aws_secret_access_key $aws_session_token
knn_stats $endpoint
run_search $endpoint $params_file $aws_access_key_id $aws_secret_access_key $aws_session_token
echo "Completed full benchmark suite at $(date)"