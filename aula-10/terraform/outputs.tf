output "instance_id" {
  description = "ID da EC2 que roda a API"
  value       = aws_instance.api.id
}

output "public_ip" {
  description = "IP publico: use no secret EC2_HOST do cd.yml"
  value       = aws_instance.api.public_ip
}

output "health_url" {
  description = "URL do health check pos-deploy"
  value       = "http://${aws_instance.api.public_ip}:${var.app_port}/health"
}
