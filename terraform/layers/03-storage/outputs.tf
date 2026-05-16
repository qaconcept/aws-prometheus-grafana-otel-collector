output "efs_file_system_id" {
  value = aws_efs_file_system.monitoring_data.id
}

output "efs_prometheus_access_point_id" {
  value = aws_efs_access_point.prometheus.id
}

output "efs_grafana_access_point_id" {
  value = aws_efs_access_point.grafana.id
}