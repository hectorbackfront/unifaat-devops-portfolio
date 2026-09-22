resource "aws_vpc" "technova" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "technova" {
  vpc_id = aws_vpc.technova.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Subnet pública — hospeda a EC2
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.technova.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
    Type = "public"
  }
}

# Subnet privada 1 — DB Subnet Group (AZ 1)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.technova.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.availability_zones[0]

  tags = {
    Name = "${var.project_name}-private-subnet-1"
    Type = "private"
  }
}

# Subnet privada 2 — DB Subnet Group (AZ 2, OBRIGATÓRIO ser diferente da 1)
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.technova.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = var.availability_zones[1]

  tags = {
    Name = "${var.project_name}-private-subnet-2"
    Type = "private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.technova.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.technova.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# As subnets privadas usam a Route Table padrão (main) da VPC, sem rota para
# o Internet Gateway — permanecem isoladas da internet.
