# Intancias front 2 regiões
resource "aws_instance" "front_a" {
  ami                         = var.ami_id
  instance_type               = var.front_instance_type
  subnet_id                   = aws_subnet.public_front_a.id
  vpc_security_group_ids      = [aws_security_group.front.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  tags = { Name = "${var.project_name}-front-a" }
}

resource "aws_instance" "front_b" {
  ami                         = var.ami_id
  instance_type               = var.front_instance_type
  subnet_id                   = aws_subnet.public_front_b.id
  vpc_security_group_ids      = [aws_security_group.front.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  tags = { Name = "${var.project_name}-front-b" }
}

# instâncias privadas em 2 regiões diferentes 
resource "aws_instance" "backend_a" {
  ami                    = var.ami_id
  instance_type          = var.backend_instance_type
  subnet_id              = aws_subnet.private_backend_a.id
  vpc_security_group_ids = [aws_security_group.backend.id]
  key_name               = var.key_name

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  tags = { Name = "${var.project_name}-backend-a" }
}

resource "aws_instance" "backend_b" {
  ami                    = var.ami_id
  instance_type          = var.backend_instance_type
  subnet_id              = aws_subnet.private_backend_b.id
  vpc_security_group_ids = [aws_security_group.backend.id]
  key_name               = var.key_name

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  tags = { Name = "${var.project_name}-backend-b" }
}

# Instância privada BD
resource "aws_instance" "db" {
  ami                    = var.ami_id
  instance_type          = var.db_instance_type
  subnet_id              = aws_subnet.private_db.id
  vpc_security_group_ids = [aws_security_group.db.id]
  key_name               = var.key_name

  user_data = <<-EOF
    #!/bin/bash
    exec > /var/log/userdata.log 2>&1
    set -x
    apt update -y
    sudo apt install mysql-server -y
  EOF

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = { Name = "${var.project_name}-db" }
}

