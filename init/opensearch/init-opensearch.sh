#!/bin/bash

# Wait for OpenSearch to be ready
echo "Waiting for OpenSearch to be ready..."
until curl -s "http://opensearch:9200/_cluster/health" > /dev/null; do
  echo "OpenSearch is unavailable - sleeping"
  sleep 5
done

echo "OpenSearch is ready!"

# Check if person_index_v2 already exists
if curl -s "http://opensearch:9200/person_index_v2" | grep -q "person_index_v2"; then
  echo "person_index_v2 already exists, skipping initialization"
  exit 0
fi

# Add index template
echo "Adding person_index_v2 template..."
curl -X PUT "http://opensearch:9200/_index_template/person_index_v2" \
  -H "Content-Type: application/json" \
  -d @/init/index_template/person_index_v2.json

# Create index
echo "Creating person_index_v2..."
curl -X PUT "http://opensearch:9200/person_index_v2"

# Import bulk data
echo "Importing test_person_bulk_100K.json..."
curl -X POST "http://opensearch:9200/person_index_v2/_bulk" \
  -H "Content-Type: application/x-ndjson" \
  --data-binary @/init/test_data/test_person_bulk_100K.json

echo "Importing test_person_special_all.json..."
curl -X POST "http://opensearch:9200/person_index_v2/_bulk" \
  -H "Content-Type: application/x-ndjson" \
  --data-binary @/init/test_data/test_person_special_all.json

# Create aliases
echo "Creating person_write alias..."
curl -X POST "http://opensearch:9200/_aliases" \
  -H "Content-Type: application/json" \
  -d '{
    "actions": [
      {
        "add": {
          "index": "person_index_v2",
          "alias": "person_write"
        }
      }
    ]
  }'

echo "Creating person_read alias for all indexes..."
curl -X POST "http://opensearch:9200/_aliases" \
  -H "Content-Type: application/json" \
  -d '{
    "actions": [
      {
        "add": {
          "index": "person_index_*",
          "alias": "person_read"
        }
      }
    ]
  }'

echo "OpenSearch initialization complete!"