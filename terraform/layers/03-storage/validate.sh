#!/bin/bash
VARS_FILE="../../central.tfvars"

EFS_ID=$(grep "^efs_file_system_id" $VARS_FILE | awk -F'=' '{print $2}' | tr -d ' "')

status_check() {
    if [ "$1" == "$2" ]; then
        echo -e "✅ $3"
    else
        echo -e "❌ $3 (Current State: $1)"
        exit 1
    fi
}

echo "--- Layer 03 Storage (EFS) Automated Validation Gate ---"

# 1. Verify EFS Existence and State
EFS_STATE=$(aws efs describe-file-systems --file-system-id "$EFS_ID" --query "FileSystems[0].LifeCycleState" --output text)
status_check "$EFS_STATE" "available" "EFS File System is Available"

# 2. Verify Mount Targets (Expecting 2)
MOUNT_COUNT=$(aws efs describe-mount-targets --file-system-id "$EFS_ID" --query "length(MountTargets)" --output text)
if [ "$MOUNT_COUNT" -ge 2 ]; then VAL="exists"; else VAL="missing"; fi
status_check "$VAL" "exists" "EFS Mount Targets provisioned across AZs ($MOUNT_COUNT found)"

echo "--- ALL LAYER 03 VALIDATIONS PASSED ---"