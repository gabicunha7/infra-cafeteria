# EFS  acessível pelas duas instâncias de front
resource "aws_efs_file_system" "app" {
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = { Name = "${var.project_name}-efs" }
}

resource "aws_efs_mount_target" "front_a" {
  file_system_id  = aws_efs_file_system.app.id
  subnet_id       = aws_subnet.public_front_a.id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "front_b" {
  file_system_id  = aws_efs_file_system.app.id
  subnet_id       = aws_subnet.public_front_b.id
  security_groups = [aws_security_group.efs.id]
}
