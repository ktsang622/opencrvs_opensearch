#!/bin/sh

FROM_INDEX=${FROM_INDEX:-person_index_v1}
TO_INDEX=${TO_INDEX:-person_index_v2}
ALIAS_NAME=${ALIAS_NAME:-person_index}

echo "⏳ Waiting for OpenSearch to be ready..."
until curl -s http://opensearch:9200 >/dev/null 2>&1; do sleep 3; done
echo "✅ OpenSearch is ready."

set -e

echo ""
echo "🔄 Reindexing from $FROM_INDEX → $TO_INDEX..."
curl -s -X POST http://opensearch:9200/_reindex \
  -H 'Content-Type: application/json' \
  -d "{
    \"source\": { \"index\": \"$FROM_INDEX\" },
    \"dest\":   { \"index\": \"$TO_INDEX\" }
  }" && echo "✅ Reindex complete."

echo ""
echo "🔗 Switching alias $ALIAS_NAME → $TO_INDEX..."

# Safely remove alias if it exists on FROM_INDEX
curl -s -X POST http://opensearch:9200/_aliases \
  -H 'Content-Type: application/json' \
  -d "{
    \"actions\": [
      { \"remove\": { \"index\": \"$FROM_INDEX\", \"alias\": \"$ALIAS_NAME\" } }
    ]
  }" || echo "⚠️ Alias may not exist yet on $FROM_INDEX"

# Add alias to TO_INDEX
curl -s -X POST http://opensearch:9200/_aliases \
  -H 'Content-Type: application/json' \
  -d "{
    \"actions\": [
      { \"add\": { \"index\": \"$TO_INDEX\", \"alias\": \"$ALIAS_NAME\" } }
    ]
  }" && echo "✅ Alias now points to $TO_INDEX."

echo ""
echo "🔍 Final alias resolution:"
curl -s http://opensearch:9200/$ALIAS_NAME/_alias

echo ""
echo "🎉 Index switch complete."
