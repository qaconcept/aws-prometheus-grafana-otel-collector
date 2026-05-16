output "ecs_cluster_id" {
  value = aws_ecs_cluster.monitoring.id
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.monitoring.name
}

output "jaeger_service_name" {
  value = aws_ecs_service.jaeger.name
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "alb_arn" {
  value = aws_lb.main.arn
}

output "https_listener_arn" {
  value = aws_lb_listener.https.arn
}