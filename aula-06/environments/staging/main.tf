data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr     = var.vpc_cidr
  project_name = var.project_name
  environment  = var.environment

  subnets = {
    "public-1"  = { cidr = "10.1.1.0/24", az = "us-east-1a", type = "public" }
    "public-2"  = { cidr = "10.1.2.0/24", az = "us-east-1b", type = "public" }
    "private-1" = { cidr = "10.1.3.0/24", az = "us-east-1a", type = "private" }
    "private-2" = { cidr = "10.1.4.0/24", az = "us-east-1b", type = "private" }
  }
}

# Security Group da API - SSH e porta da aplicacao
module "api_sg" {
  source = "../../modules/security-group"

  name         = "${var.project_name}-${var.environment}-api-sg"
  vpc_id       = module.vpc.vpc_id # <- Composicao: VPC -> SG
  project_name = var.project_name
  environment  = var.environment

  ingress_rules = [
    {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "API Node.js"
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# Security Group do RDS - PostgreSQL apenas a partir do SG da API
module "rds_sg" {
  source = "../../modules/security-group"

  name         = "${var.project_name}-${var.environment}-rds-sg"
  vpc_id       = module.vpc.vpc_id # <- Composicao: VPC -> SG
  project_name = var.project_name
  environment  = var.environment

  ingress_rules = [
    {
      description     = "PostgreSQL apenas da API"
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [module.api_sg.sg_id] # <- Composicao: SG -> SG
    }
  ]
}

module "api_server" {
  source = "../../modules/ec2"

  instance_name      = "${var.project_name}-${var.environment}-api"
  ami_id             = data.aws_ami.amazon_linux.id
  subnet_id          = module.vpc.public_subnet_ids[0] # <- Composicao: VPC -> EC2
  security_group_ids = [module.api_sg.sg_id]           # <- Composicao: SG -> EC2
  key_name           = var.key_name
  project_name       = var.project_name
  environment        = var.environment
}

module "database" {
  source = "../../modules/rds"

  db_name            = "technova_${var.environment}"
  db_username        = "technova_admin"
  db_password        = var.db_password
  subnet_ids         = module.vpc.private_subnet_ids # <- Composicao: VPC -> RDS
  security_group_ids = [module.rds_sg.sg_id]         # <- Composicao: SG -> RDS
  project_name       = var.project_name
  environment        = var.environment
}
