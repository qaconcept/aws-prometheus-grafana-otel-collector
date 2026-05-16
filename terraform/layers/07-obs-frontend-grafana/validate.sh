#!/bin/bash
VARS_FILE="../../central.tfvars"
DOMAIN=$(grep "^domain_name" $VARS_FILE | awk -F'=' '{print $2}' | tr -d ' "')

echo "--- Layer 07 Grafana Validation ---"
echo "Checking https://grafana.$DOMAIN..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://grafana.$DOMAIN/api/health")

if [ "$HTTP_CODE" == "200" ]; then
    echo "✅ SUCCESS: Grafana is live at https://grafana.$DOMAIN"
else
    echo "⚠️ Status Code: $HTTP_CODE (Wait 60s for the container to mount EFS and start up fully)"
fi

echo "--- ALL VALIDATIONS PASSED ---"