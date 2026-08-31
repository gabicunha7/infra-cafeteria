# VPC 
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.project_name}-igw" }
}

# Subnets Públicas
resource "aws_subnet" "public_front_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_front_a_cidr
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-front-a" }
}

resource "aws_subnet" "public_front_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_front_b_cidr
  availability_zone       = var.availability_zones[1]
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-front-b" }
}


# Subnets Privadas
resource "aws_subnet" "private_backend_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_backend_a_cidr
  availability_zone = var.availability_zones[0]

  tags = { Name = "${var.project_name}-private-backend-a" }
}

resource "aws_subnet" "private_backend_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_backend_b_cidr
  availability_zone = var.availability_zones[1]

  tags = { Name = "${var.project_name}-private-backend-b" }
}

resource "aws_subnet" "private_db" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_db_cidr
  availability_zone = var.availability_zones[0]

  tags = { Name = "${var.project_name}-private-db" }
}

# RT publica e igw
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${var.project_name}-rt-public" }
}

resource "aws_route_table_association" "public_front_a" {
  subnet_id      = aws_subnet.public_front_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_front_b" {
  subnet_id      = aws_subnet.public_front_b.id
  route_table_id = aws_route_table.public.id
}


# NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-eip-nat" }
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_front_a.id

  tags       = { Name = "${var.project_name}-ngw" }
  depends_on = [aws_internet_gateway.igw]
}

# RT privada e NAT gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }

  tags = { Name = "${var.project_name}-rt-private" }
}

resource "aws_route_table_association" "private_backend_a" {
  subnet_id      = aws_subnet.private_backend_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_backend_b" {
  subnet_id      = aws_subnet.private_backend_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_db" {
  subnet_id      = aws_subnet.private_db.id
  route_table_id = aws_route_table.private.id
}
