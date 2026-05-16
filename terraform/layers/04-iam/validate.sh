#!/bin/bash
VARS_FILE="../../central.tfvars"

EXEC_ARN=$(grep "^ecs_task_execution_role_arn" $VARS_FILE | awk -F'=' '{print $2}' | tr -d ' "')
TASK_ARN=$(grep "^ecs_task_role_arn" $VARS_FILE | awk -F'=' '{print $2}' | tr -d ' "')

status_check() {
    if [ "$1" == "$2" ]; then
        echo -e "✅ $3"
    else
        echo -e "❌ $3 (Current State: $1)"
        exit 1
    fi
}

echo "--- Layer 04 IAM Automated Validation Gate ---"

# 1. Verify Execution Role Trust Relationship
EXEC_TRUST=$(aws iam get-role --role-name $(basename $EXEC_ARN) --query "Role.AssumeRolePolicyDocument.Statement[0].Principal.Service" --output text)
status_check "$EXEC_TRUST" "ecs-tasks.amazonaws.com" "Execution Role trust relationship verified"

# 2. Verify Task Role Policy Attachment
POLICY_COUNT=$(aws iam list-attached-role-policies --role-name $(basename $TASK_ARN) --query "length(AttachedPolicies)" --output text)
if [ "$POLICY_COUNT" -ge 1 ]; then VAL="exists"; else VAL="missing"; fi
status_check "$VAL" "exists" "Task Role has policies attached"

echo "--- ALL LAYER 04 VALIDATIONS PASSED ---"