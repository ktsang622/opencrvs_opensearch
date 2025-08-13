#!/bin/bash
set -e

echo "Starting production services..."
yarn start

echo "Waiting for services to be ready..."
sleep 30

echo "Seeding data..."
yarn seed:prod

echo "Production environment is ready!"
echo "OpenSearch: http://localhost:19200"
echo "Dashboards: http://localhost:5601"
echo "Adminer: http://localhost:15432"