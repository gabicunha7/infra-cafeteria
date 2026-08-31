# ALB Público  
resource "aws_security_group" "alb_public" {
  name        = "${var.project_name}-alb-public"
  description = "Security group do ALB publico (front)"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP publico"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alb-public" }
}

# Instâncias de Front
resource "aws_security_group" "front" {
  name        = "${var.project_name}-front"
  description = "Security group das instancias de frontend"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "HTTP vindo do ALB publico"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_public.id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description = "Node Exporter (apenas da VPC)"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-front" }
}

# ALB Interno 
resource "aws_security_group" "alb_internal" {
  name        = "${var.project_name}-alb-internal"
  description = "Security group do ALB interno (backend) - so aceita trafego das instancias de front"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Backend vindo das instancias de front"
    from_port       = var.backend_port
    to_port         = var.backend_port
    protocol        = "tcp"
    security_groups = [aws_security_group.front.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alb-internal" }
}

# Instâncias de Back
resource "aws_security_group" "backend" {
  name        = "${var.project_name}-backend"
  description = "Security group das instancias de backend privadas"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Backend vindo do ALB interno"
    from_port       = var.backend_port
    to_port         = var.backend_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_internal.id]
  }

  ingress {
    description = "SSH (apenas da VPC)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Node Exporter (apenas da VPC)"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-backend" }
}

# Instância do BD
resource "aws_security_group" "db" {
  name        = "${var.project_name}-db"
  description = "Security group da instancia de banco de dados"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Banco de dados vindo do backend"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  ingress {
    description = "SSH (apenas da VPC)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Node Exporter (apenas da VPC)"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-db" }
}

# EFS para 2 de front
resource "aws_security_group" "efs" {
  name        = "${var.project_name}-efs"
  description = "Security group do EFS - NFS restrito as instancias de front"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "NFS vindo das instancias de front"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.front.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-efs" }
}

