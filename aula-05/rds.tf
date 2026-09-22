# DB Subnet Group — requer subnets em 2+ AZs diferentes
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-db"

  engine         = "postgres"
  engine_version = "15"

  # Capacidade — Free Tier
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # Alta disponibilidade desligada — não é Free Tier
  multi_az = false

  # Backups automáticos desligados para simplificar/agilizar o lab
  backup_retention_period = 0

  storage_encrypted = true

  # Lab: sem snapshot final ao destruir. NUNCA fazer isso em produção.
  skip_final_snapshot = true

  performance_insights_enabled = false

  tags = {
    Name = "${var.project_name}-rds"
  }
}
