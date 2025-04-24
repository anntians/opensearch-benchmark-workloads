#!/bin/bash

# Exit on any error
set -xe

run_indexing() {
  echo "Running Indexing using ${1} and params: ${2} $(date)"
  opensearch-benchmark execute-test \
      --target-hosts $1     \
      --workload vectorsearch     \
      --workload-params $2     \
      --pipeline benchmark-only     \
      --kill-running-processes \
      --test-procedure=no-train-test-index-only \
      --exclude-tasks "delete-target-index" \
      --client-options=timeout:1200
}

run_force_merge() {
  echo "Running Force Merge using ${1} and params: ${2} $(date)"
  opensearch-benchmark execute-test \
      --target-hosts $1     \
      --workload vectorsearch     \
      --workload-params $2     \
      --pipeline benchmark-only     \
      --kill-running-processes \
      --test-procedure=force-merge-index \
      --client-options=timeout:1200
}

run_search() {
  echo "Running Search using ${1} and params: ${2} $(date)"
  opensearch-benchmark execute-test \
      --target-hosts $1     \
      --workload vectorsearch     \
      --workload-params $2     \
      --pipeline benchmark-only     \
      --kill-running-processes \
      --test-procedure=search-only \
      --client-options=timeout:1200
}

enable_graph_builds() {
  echo "Flushing the index... $(date)"
  curl --request GET --url $1/target_index/_flush
  echo "Sleeping for 5 mins to ensure that graph builds triggered due to flush are completed... $(date)"
  sleep 300
  echo "Enabling Graph Builds... $(date)"
  curl --request PUT \
  --url $1/target_index/_settings \
  --header 'Content-Type: application/json' \
  --data '{
  "index.knn.advanced.approximate_threshold": "0"
  }'
}

setup_cluster() {

  echo "Setting up cluster using ${1} and coordinator ${2} $(date)"
  curl --request PUT \
    --url $1/_cluster/settings \
    --header 'Content-Type: application/json' \
    --data '{
      "persistent": {
        "knn.remote_index_build.repository" : "vector-repo",
        "knn.remote_index_build.enabled" : "true",
        "knn.remote_index_build.service.endpoint": "'$2'",
        "logger.org.opensearch.knn" : "DEBUG"
      }
  }'

#  "knn.memory.circuit_breaker.limit" : "60%",
#  "knn.remote_index_build.client.poll_interval" : "1s"
}

setup_cluster_baseline() {

  echo "Setting up cluster baseline using ${1} $(date)"
  curl --request PUT \
    --url $1/_cluster/settings \
    --header 'Content-Type: application/json' \
    --data '{
      "persistent": {
        "knn.feature.remote_index_build.enabled" : "false",
        "logger.org.opensearch.knn" : "DEBUG",
        "knn.memory.circuit_breaker.limit" : "60%"
      }
  }'
}

setup_repo() {
  echo "Setting up repo using ${1} $(date)"
    curl --request PUT \
      --url $1/_snapshot/vector-repo \
      --header 'Content-Type: application/json' \
      --data '{
          "type": "s3",
          "settings": {
          "bucket": "remote-build-benchmarking",
          "base_path": "vectors",
          "region": "us-west-2",
          "s3_upload_retry_enabled": true
        }
    }'
}

# Function to display usage
usage() {
    cat << EOF
Usage: $(basename $0) <options>

Options:
    -e, --endpoint            AWS endpoint
    -p, --params-file        Parameters file
    -a, --access-key         AWS access key
    -s, --secret-key         AWS secret key
    -c, --coordinator-endpoint    Coordinator endpoint
    -t, --coordinator-port       Coordinator port
    -h, --help              Show this help message

Example:
    $(basename $0) -e https://aws.endpoint.com -p params.json -a AKIAXXXXXX -s secretkey -c coordinator.example.com -t 8080
EOF
    exit 1
}

# Function to handle parameters
run_benchmark() {
    local endpoint=""
    local params_file=""
    local coordinator_endpoint=""
    local index=""

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--endpoint)
                endpoint="$2"
                shift 2
                ;;
            -p|--params-file)
                params_file="$2"
                shift 2
                ;;
            -c|--coordinator-endpoint)
                coordinator_endpoint="$2"
                shift 2
                ;;
            -i|--index)
                index="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Unknown option: $1 $(date)"
                usage
                ;;
        esac
    done

    # Validate required parameters
    if [[ -z "$endpoint" ]] || [[ -z "$params_file" ]] || [[ -z "$coordinator_endpoint" ]] || [[ -z "$index" ]]; then
        echo "Error: Missing required parameters $(date)"
        usage
    fi

    # Export the variables
    export ENDPOINT="$endpoint"
    export PARAMS_FILE="$params_file"
    export COORDINATOR_ENDPOINT="$coordinator_endpoint"
    export TARGET_INDEX="$index"

    setup_cluster $ENDPOINT $COORDINATOR_ENDPOINT

#    setup_cluster_baseline $ENDPOINT

    setup_repo $ENDPOINT

    #delete index
    curl -X DELETE "$ENDPOINT/$TARGET_INDEX"

    run_indexing  $ENDPOINT $PARAMS_FILE

    #enable_graph_builds $ENDPOINT

    run_force_merge  $ENDPOINT $PARAMS_FILE

    #run_search $ENDPOINT $PARAMS_FILE
}

# Main execution
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
    # Script is being run directly
    if [[ $# -eq 0 ]]; then
        usage
    fi
    run_benchmark "$@"
fi