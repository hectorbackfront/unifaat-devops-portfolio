output "vpc_id" {
  description = "ID da VPC do ambiente"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs das subnets publicas"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas"
  value       = module.vpc.private_subnet_ids
}

output "api_public_ip" {
  description = "IP publico da instancia da API"
  value       = module.api_server.public_ip
}

output "db_endpoint" {
  description = "Endpoint de conexao do RDS"
  value       = module.database.db_endpoint
}

output "db_name" {
  description = "Nome do banco de dados"
  value       = module.database.db_name
}
