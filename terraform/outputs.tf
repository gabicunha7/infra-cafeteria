# Load Balancers 
output "alb_public_dns" {
  description = "DNS do ALB publico roteia entre front a e front b"
  value       = aws_lb.public.dns_name
}

output "alb_backend_dns" {
  description = "DNS do ALB interno do backend - usado no front-end em vez do IP de uma instancia"
  value       = aws_lb.internal.dns_name
}

#  Instâncias de Front 
output "front_a_public_ip" {
  description = "IP publico da instancia front-a"
  value       = aws_instance.front_a.public_ip
}

output "front_b_public_ip" {
  description = "IP publico da instancia front-b"
  value       = aws_instance.front_b.public_ip
}

#  Instâncias de Backend 
output "backend_a_private_ip" {
  description = "IP privado da instancia backend-a"
  value       = aws_instance.backend_a.private_ip
}

output "backend_b_private_ip" {
  description = "IP privado da instancia backend-b"
  value       = aws_instance.backend_b.private_ip
}

# Banco de Dados 
output "db_private_ip" {
  description = "IP privado da instancia de banco de dados"
  value       = aws_instance.db.private_ip
}


# EFS 
output "efs_id" {
  description = "ID do EFS"
  value       = aws_efs_file_system.app.id
}

output "efs_dns_name" {
  description = "DNS do EFS para montagem nas instancias de front"
  value       = aws_efs_file_system.app.dns_name
}

#  S3 (data lake, medalhão) 
output "s3_bucket_names" {
  description = "Nomes reais dos 3 buckets criados (raw, trusted, client)"
  value       = { for k, b in aws_s3_bucket.data : k => b.bucket }
}

output "s3_bucket_arns" {
  description = "ARNs dos 3 buckets criados"
  value       = { for k, b in aws_s3_bucket.data : k => b.arn }
}
