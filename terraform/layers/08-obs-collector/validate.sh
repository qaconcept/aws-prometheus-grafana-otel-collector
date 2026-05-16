#!/bin/bash
VARS_FILE="../../central.tfvars"
CLUSTER=$(grep "^project_name" $VARS_FILE | awk -F'=' '{print $2}' | tr -d ' "')-cluster

echo "--- Layer 08 OTel Collector Validation ---"
echo "Verifying Task Health inside ECS..."

# Capture any running task ARNs for the collector
RUNNING_TASKS=$(aws ecs list-tasks --cluster "$CLUSTER" --service-name "sre-concepts-otel-collector" --desired-status RUNNING --query "taskArns" --output text)

# Corrected using modern bash double brackets and the standard '!' operator
if [[ ! -z "$RUNNING_TASKS" ]]; then
    echo "✅ SUCCESS: OpenTelemetry Collector service is active and running tasks."
else
    echo "❌ Error: No running tasks found for the OTel Collector service."
    exit 1
fi

echo "--- ALL VALIDATIONS PASSED ---"