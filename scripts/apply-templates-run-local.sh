#!/bin/bash

set -e

TEMPLATE_PATH="../init/index_template/person_index_v2.json"
INDEX_TEMPLATE_NAME="person_index_v3"
OS_FULL_HOST="${OS_FULL_HOST:-http://localhost:9200}"
OPENSEARCH_ADMIN_PASSWORD="${OPENSEARCH_ADMIN_PASSWORD:-WelcomeDemo1.23@}"

if [ -z "$OS_FULL_HOST" ] || [ -z "$OPENSEARCH_ADMIN_PASSWORD" ]; then
  echo "❌ Please set OS_FULL_HOST and OPENSEARCH_ADMIN_PASSWORD in your .env or export them."
  exit 1
fi

echo "Deleting existing template: $INDEX_TEMPLATE_NAME (if exists)..."

curl -X DELETE "$OS_FULL_HOST/_index_template/$INDEX_TEMPLATE_NAME" \
  -u "admin:${OPENSEARCH_ADMIN_PASSWORD}" \
  --insecure \
  --silent \
  --output /dev/null || true


echo "Applying index template to $OS_FULL_HOST..."

curl -X PUT "$OS_FULL_HOST/_index_template/$INDEX_TEMPLATE_NAME" \
  -H "Content-Type: application/json" \
  -u "admin:${OPENSEARCH_ADMIN_PASSWORD}" \
  --insecure \
  --data-binary "@$TEMPLATE_PATH"

echo "Template applied successfully."

