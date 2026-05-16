#!/bin/bash
VARS_FILE="../../central.tfvars"

# Robust parsing: matches line starting with vpc_id, gets value after =, removes quotes/spaces
VPC_ID=$(grep "^vpc_id" $VARS_FILE | awk -F'=' '{print $2}' | tr -d ' "')

status_check() {
    if [ "$1" == "$2" ]; then
        echo -e "✅ $3"
    else
        echo -e "❌ $3 (Current State: $1)"
        exit 1
    fi
}

echo "--- Layer 01 VPC Automated Validation Gate ---"

if [ -z "$VPC_ID" ]; then
    echo "❌ Error: VPC_ID not found in $VARS_FILE. Run sync-vars.sh first."
    exit 1
fi

echo "Targeting VPC: $VPC_ID"

# 1. Verify VPC State
VPC_STATE=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --query "Vpcs[0].State" --output text 2>/dev/null)
status_check "$VPC_STATE" "available" "VPC is Available"

# 2. Verify Public Subnets (Expecting 2)
echo "Checking Public Subnets..."
PUB_SUB_COUNT=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*public*" --query "length(Subnets)" --output text)
if [ "$PUB_SUB_COUNT" -ge 2 ]; then S_VAL="exists"; else S_VAL="missing"; fi
status_check "$S_VAL" "exists" "Public Subnets are provisioned ($PUB_SUB_COUNT found)"

# 3. Verify Private Subnets (Expecting 2)
echo "Checking Private Subnets..."
PRIV_SUB_COUNT=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*private*" --query "length(Subnets)" --output text)
if [ "$PRIV_SUB_COUNT" -ge 2 ]; then S_VAL="exists"; else S_VAL="missing"; fi
status_check "$S_VAL" "exists" "Private Subnets are provisioned ($PRIV_SUB_COUNT found)"

# 4. Verify NAT Gateway
echo "Checking NAT Gateway status..."
NAT_STATE=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --query "NatGateways[?State!='deleted'].State | [0]" --output text)
status_check "$NAT_STATE" "available" "NAT Gateway is Available"

echo "--- ALL LAYER 01 VALIDATIONS PASSED ---"