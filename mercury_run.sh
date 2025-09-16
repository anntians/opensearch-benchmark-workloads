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
      --client-options="basic_auth_user:'$3',basic_auth_password:'$4',timeout:1200"
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
      --client-options="basic_auth_user:'$3',basic_auth_password:'$4',timeout:1200"
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
      --client-options="basic_auth_user:'$3',basic_auth_password:'$4',timeout:1200"
  echo "Completed Search at $(date)"
}

knn_stats() {
  echo "KNN Stats at $(date)"
  curl -u "$2:$3" "$1/_plugins/_knn/stats?pretty"
  echo ""
}

# Function to display usage
usage() {
    cat << EOF
Usage: $(basename $0) <endpoint> <params-file> <username> <password> <target-index>

Arguments:
    endpoint        OpenSearch cluster endpoint
    params-file     Parameters file for the workload
    username        Authentication username
    password        Authentication password
    target-index    Target index name

Example:
    $(basename $0) https://aws.endpoint.com params.json pfUser "pfUser@123" target_index
EOF
    exit 1
}

# Main execution
if [[ $# -ne 5 ]]; then
    usage
fi

endpoint="$1"
params_file="$2"
username="$3"
password="$4"
target_index="$5"

echo "Starting full benchmark suite at $(date)"
knn_stats $endpoint $username $password
run_indexing $endpoint $params_file $username $password
knn_stats $endpoint $username $password
run_force_merge $endpoint $params_file $username $password
knn_stats $endpoint $username $password
run_search $endpoint $params_file $username $password
echo "Completed full benchmark suite at $(date)"