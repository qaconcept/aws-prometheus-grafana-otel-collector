#!/bin/bash
VARS_FILE="../../central.tfvars"

# Extract IDs from central.tfvars
ALB_SG_ID=$(grep "^alb_security_group_id" $VARS_FILE | awk -F'=' '{print $2}' | tr -d ' "')
ECS_SG_ID=$(grep "^ecs_tasks_security_group_id" $VARS_FILE | awk -F'=' '{print $2}' | tr -d ' "')

status_check() {
    if [ "$1" == "$2" ]; then
        echo -e "✅ $3"
    else
        echo -e "❌ $3 (Current State: $1)"
        exit 1
    fi
}

echo "--- Layer 02 Security Group Automated Validation Gate ---"

# 1. Verify ALB SG Ingress (Strict Port 443)
echo "Verifying ALB Security Group..."
HTTPS_OPEN=$(aws ec2 describe-security-groups --group-ids "$ALB_SG_ID" --query "SecurityGroups[0].IpPermissions[?ToPort==\`443\`].IpRanges[0].CidrIp" --output text)
status_check "$HTTPS_OPEN" "0.0.0.0/0" "ALB SG allows Port 443 from Global"

# 2. Verify ECS Task SG Source (Must be ALB SG)
echo "Verifying ECS Task Security Group source..."
SOURCE_SG=$(aws ec2 describe-security-groups --group-ids "$ECS_SG_ID" --query "SecurityGroups[0].IpPermissions[0].UserIdGroupPairs[0].GroupId" --output text)
status_check "$SOURCE_SG" "$ALB_SG_ID" "ECS Task SG source restricted to ALB SG"

echo "--- ALL LAYER 02 VALIDATIONS PASSED ---"