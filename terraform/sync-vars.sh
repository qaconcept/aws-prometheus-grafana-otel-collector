#!/bin/bash

VARS_FILE="central.tfvars"
LAYER=$1

# Helper function to update value if exists, or append if new
update_var() {
    local key=$1
    local value=$2
    if grep -q "^${key} =" "$VARS_FILE"; then
        # Fixed for macOS sed compliance using -i ""
        sed -i "" "s|^${key} =.*|${key} = ${value}|" "$VARS_FILE"
    else
        echo "${key} = ${value}" >> "$VARS_FILE"
    fi
}

case $LAYER in
  "01")
    echo "Updating Layer 01..."
    update_var "vpc_id" "\"$(terraform -chdir=layers/01-vpc output -raw vpc_id)\""
    update_var "public_subnets" "$(terraform -chdir=layers/01-vpc output -json public_subnets)"
    update_var "private_subnets" "$(terraform -chdir=layers/01-vpc output -json private_subnets)"
    ;;
  "02")
    echo "Updating Layer 02..."
    update_var "alb_security_group_id" "\"$(terraform -chdir=layers/02-ingress-egress output -raw alb_security_group_id)\""
    update_var "ecs_tasks_security_group_id" "\"$(terraform -chdir=layers/02-ingress-egress output -raw ecs_tasks_security_group_id)\""
    ;;
  "03")
    echo "Updating Layer 03..."
    update_var "efs_file_system_id" "\"$(terraform -chdir=layers/03-storage output -raw efs_file_system_id)\""
    update_var "efs_prometheus_access_point_id" "\"$(terraform -chdir=layers/03-storage output -raw efs_prometheus_access_point_id)\""
    update_var "efs_grafana_access_point_id" "\"$(terraform -chdir=layers/03-storage output -raw efs_grafana_access_point_id)\""
    ;;
  "04")
    echo "Updating Layer 04..."
    update_var "ecs_task_execution_role_arn" "\"$(terraform -chdir=layers/04-iam output -raw ecs_task_execution_role_arn)\""
    update_var "ecs_task_role_arn" "\"$(terraform -chdir=layers/04-iam output -raw ecs_task_role_arn)\""
  # Add this line to map the role for Layer 09:
    update_var "ecs_exec_role_arn" "\"$(terraform -chdir=layers/04-iam output -raw ecs_task_execution_role_arn)\""
    ;;
  "05")
    echo "Updating Layer 05..."
    update_var "ecs_cluster_id" "\"$(terraform -chdir=layers/05-obs-backend-jaeger output -raw ecs_cluster_id)\""
    update_var "cluster_name" "\"$(terraform -chdir=layers/05-obs-backend-jaeger output -raw ecs_cluster_name)\""
    update_var "alb_dns_name" "\"$(terraform -chdir=layers/05-obs-backend-jaeger output -raw alb_dns_name)\""
    update_var "alb_arn" "\"$(terraform -chdir=layers/05-obs-backend-jaeger output -raw alb_arn)\""
    update_var "https_listener_arn" "\"$(terraform -chdir=layers/05-obs-backend-jaeger output -raw https_listener_arn)\""
    ;;
  "06")
    echo "Updating Layer 06..."
    update_var "prometheus_service_name" "\"$(terraform -chdir=layers/06-obs-backend-prometheus output -raw prometheus_service_name)\""
    ;;
  "07")
    echo "Updating Layer 07..."
    # Pointing to the correct folder name matching our structure
    update_var "grafana_service_name" "\"$(terraform -chdir=layers/07-obs-frontend-grafana output -raw grafana_service_name)\""
    ;;
  "08")
    echo "Updating Layer 08..."
    update_var "otel_service_name" "\"$(terraform -chdir=layers/08-obs-collector output -raw otel_service_name)\""
    ;;
  *)
    echo "Usage: ./sync-vars.sh [01|02|03|04|05|06|07|08]"
    ;;
esac
echo "Done."