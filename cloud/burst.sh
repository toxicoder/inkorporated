#!/bin/bash
set -e

# Cloud Bursting Script
# Usage: ./burst.sh <number_of_nodes> [provider]

NODE_COUNT=$1
PROVIDER=${2:-aws}

if [ -z "$NODE_COUNT" ]; then
    echo "Usage: $0 <number_of_nodes> [provider]"
    exit 1
fi

echo "Scaling cloud infrastructure to $NODE_COUNT nodes on $PROVIDER..."

cd infrastructure/terraform

terraform apply \
  -var="hybrid_enable=true" \
  -var="cloud_provider=$PROVIDER" \
  -var="cloud_node_count=$NODE_COUNT" \
  -auto-approve

echo "Scaling complete."
