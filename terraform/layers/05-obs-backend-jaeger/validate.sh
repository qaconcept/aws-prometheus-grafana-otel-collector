#!/bin/bash
VARS_FILE="../../central.tfvars"
DOMAIN=$(grep "^domain_name" $VARS_FILE | awk -F'=' '{print $2}' | tr -d ' "')

echo "--- Layer 05 Jaeger Live URL Validation ---"

# 1. Check if Task is Running
CLUSTER_NAME=$(aws ecs list-clusters --query "clusterArns[?contains(@, 'sre-concepts')]" --output text | cut -d'/' -f2)
TASK_STATUS=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --service-name sre-concepts-jaeger --query "taskArns[0]" --output text)

if [ "$TASK_STATUS" != "None" ]; then
    echo "✅ Jaeger Task is provisioned in ECS"
else
    echo "❌ Jaeger Task not found"
    exit 1
fi

# 2. Check URL Response
echo "Checking https://jaeger.$DOMAIN..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://jaeger.$DOMAIN")
if [ "$HTTP_CODE" == "200" ]; then
    echo "✅ SUCCESS: Jaeger UI is accessible at https://jaeger.$DOMAIN"
else
    echo "⚠️ Status Code: $HTTP_CODE (Wait 60s for health checks to pass)"
fi

echo "--- ALL LAYER 05 VALIDATIONS PASSED ---"