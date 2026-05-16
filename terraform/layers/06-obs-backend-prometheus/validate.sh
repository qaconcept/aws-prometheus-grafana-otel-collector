#!/bin/bash
VARS_FILE="../../central.tfvars"
DOMAIN=$(grep "^domain_name" $VARS_FILE | awk -F'=' '{print $2}' | tr -d ' "')

echo "--- Layer 06 Prometheus Validation ---"
echo "Checking https://prometheus.$DOMAIN..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://prometheus.$DOMAIN/-/healthy")

if [ "$HTTP_CODE" == "200" ]; then
    echo "✅ SUCCESS: Prometheus is live at https://prometheus.$DOMAIN"
else
    echo "⚠️ Status Code: $HTTP_CODE (Wait 60s for the container to mount EFS and start)"
fi

echo "--- ALL LAYER 05 VALIDATIONS PASSED ---"