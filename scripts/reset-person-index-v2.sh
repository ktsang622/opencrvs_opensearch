#!/bin/sh

INDEX_VERSION=v2
INDEX_NAME="person_index_${INDEX_VERSION}"
TEMPLATE_NAME="person-index-template_${INDEX_VERSION}"
SETTINGS_TEMPLATE="init/component_template/settings-person_${INDEX_VERSION}.json"
MAPPINGS_TEMPLATE="init/component_template/mappings-person_${INDEX_VERSION}.json"
INDEX_TEMPLATE="init/index_template/person_index_${INDEX_VERSION}.json"

echo "⏳ Deleting index $INDEX_NAME (if exists)..."
curl -s -X DELETE "http://opensearch:9200/$INDEX_NAME" && echo "✅ Deleted." || echo "⚠️ Index not found."

echo ""
echo "⚙️ Reapplying component templates..."
curl -s -X PUT "http://opensearch:9200/_component_template/settings-person_${INDEX_VERSION}" \
  -H 'Content-Type: application/json' -d @"$SETTINGS_TEMPLATE" && echo "✅ Settings applied."
curl -s -X PUT "http://opensearch:9200/_component_template/mappings-person_${INDEX_VERSION}" \
  -H 'Content-Type: application/json' -d @"$MAPPINGS_TEMPLATE" && echo "✅ Mappings applied."

echo ""
echo "📦 Reapplying index template $TEMPLATE_NAME..."
curl -s -X PUT "http://opensearch:9200/_index_template/$TEMPLATE_NAME" \
  -H 'Content-Type: application/json' -d @"$INDEX_TEMPLATE" && echo "✅ Index template applied."

echo ""
echo "📁 Recreating index $INDEX_NAME..."
curl -s -X PUT "http://opensearch:9200/$INDEX_NAME" \
  -H 'Content-Type: application/json' -d '{}' && echo "✅ Index created."

echo ""
echo "📌 Final mapping verification:"
curl -s "http://opensearch:9200/$INDEX_NAME/_mapping?pretty" | grep linked_persons && echo "✅ nested field present." || echo "❌ linked_persons missing!"
