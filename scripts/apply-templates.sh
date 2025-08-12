#!/bin/sh

INDEX_VERSION=${INDEX_VERSION:-v2}
SETTINGS_TEMPLATE="/component_template/settings-person_${INDEX_VERSION}.json"
MAPPINGS_TEMPLATE="/component_template/mappings-person_${INDEX_VERSION}.json"
INDEX_TEMPLATE="/index_template/person_index_${INDEX_VERSION}.json"
INDEX_NAME="person_index_${INDEX_VERSION}"
TEMPLATE_NAME="person-index-template_${INDEX_VERSION}"

echo "🔍 Verifying file paths..."
echo "SETTINGS_TEMPLATE: $SETTINGS_TEMPLATE"
echo "MAPPINGS_TEMPLATE: $MAPPINGS_TEMPLATE"
echo "INDEX_TEMPLATE: $INDEX_TEMPLATE"
echo "INDEX_NAME: $INDEX_NAME"
echo "TEMPLATE_NAME: $TEMPLATE_NAME"

echo "⏳ Waiting for OpenSearch to be ready..."
until curl -s http://opensearch:9200 >/dev/null 2>&1; do sleep 3; done
echo "✅ OpenSearch is ready."

set -e

echo ""
echo "⚙️ Applying component templates for version $INDEX_VERSION..."

curl -s -X PUT http://opensearch:9200/_component_template/settings-person_${INDEX_VERSION} \
  -H 'Content-Type: application/json' \
  -d @"$SETTINGS_TEMPLATE" && echo "✅ Settings applied."

curl -s -X PUT http://opensearch:9200/_component_template/mappings-person_${INDEX_VERSION} \
  -H 'Content-Type: application/json' \
  -d @"$MAPPINGS_TEMPLATE" && echo "✅ Mappings applied."

echo ""
echo "📦 Applying index template: $TEMPLATE_NAME..."
curl -s -X PUT http://opensearch:9200/_index_template/$TEMPLATE_NAME \
  -H 'Content-Type: application/json' \
  -d @"$INDEX_TEMPLATE" && echo "✅ Index template applied."

echo ""
echo "📁 Creating index: $INDEX_NAME..."
curl -s -X PUT http://opensearch:9200/$INDEX_NAME \
  -H 'Content-Type: application/json' \
  -d '{}' \
  && echo "✅ Index $INDEX_NAME created." \
  || echo "⚠️ Index may already exist."

echo ""
echo "🎉 Bootstrap for version $INDEX_VERSION complete."
