variable "region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "Informe uma região AWS válida, ex: us-east-1."
  }
}

variable "project_name" {
  description = "Prefixo usado no nome de todos os recursos"
  type        = string
  default     = "cafeteria"
}

variable "availability_zones" {
  description = "As 2 zonas de disponibilidade usadas por toda a infraestrutura (posição 0 = AZ-a, posição 1 = AZ-b)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Esta infraestrutura foi desenhada para usar exatamente 2 AZs."
  }
}

# VPC 
variable "vpc_cidr" {
  description = "Bloco CIDR da VPC"
  type        = string
  default     = "10.0.0.0/20"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr precisa ser um bloco CIDR válido."
  }
}

# Subnets públicas
variable "public_front_a_cidr" {
  description = "Subnet pública da instância front-a (AZ-a)"
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrhost(var.public_front_a_cidr, 0))
    error_message = "public_front_a_cidr precisa ser um bloco CIDR válido."
  }
}

variable "public_front_b_cidr" {
  description = "Subnet pública da instância front-b (AZ-b)"
  type        = string
  default     = "10.0.2.0/24"

  validation {
    condition     = can(cidrhost(var.public_front_b_cidr, 0))
    error_message = "public_front_b_cidr precisa ser um bloco CIDR válido."
  }
}


# Subnets privadas
variable "private_backend_a_cidr" {
  description = "Subnet privada da instância backend-a (AZ-a)"
  type        = string
  default     = "10.0.4.0/24"

  validation {
    condition     = can(cidrhost(var.private_backend_a_cidr, 0))
    error_message = "private_backend_a_cidr precisa ser um bloco CIDR válido."
  }
}

variable "private_backend_b_cidr" {
  description = "Subnet privada da instância backend-b (AZ-b)"
  type        = string
  default     = "10.0.5.0/24"

  validation {
    condition     = can(cidrhost(var.private_backend_b_cidr, 0))
    error_message = "private_backend_b_cidr precisa ser um bloco CIDR válido."
  }
}

variable "private_db_cidr" {
  description = "Subnet privada da instância de banco de dados"
  type        = string
  default     = "10.0.6.0/24"

  validation {
    condition     = can(cidrhost(var.private_db_cidr, 0))
    error_message = "private_db_cidr precisa ser um bloco CIDR válido."
  }
}

# EC2
variable "ami_id" {
  description = "AMI usada em todas as instâncias (Ubuntu)"
  type        = string
  default     = "ami-0360c520857e3138f"
}

variable "front_instance_type" {
  description = "Tipo das instâncias de frontend"
  type        = string
  default     = "t3.small"
}

variable "backend_instance_type" {
  description = "Tipo das instâncias de backend"
  type        = string
  default     = "t3.small"
}

variable "db_instance_type" {
  description = "Tipo da instância de banco de dados"
  type        = string
  default     = "t3.medium"
}


variable "key_name" {
  description = "Nome do par de chaves EC2 para ssh"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR autorizado a acessar as instâncias via SSH (porta 22). só para dev."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0))
    error_message = "ssh_allowed_cidr precisa ser um bloco CIDR válido."
  }
}

variable "backend_port" {
  description = "Porta em que a aplicação de backend escuta"
  type        = number
  default     = 8080

  validation {
    condition     = var.backend_port > 0 && var.backend_port <= 65535
    error_message = "backend_port precisa estar entre 1 e 65535."
  }
}

variable "db_port" {
  description = "Porta do serviço de banco de dados rodando na instância privada"
  type        = number
  default     = 3306

  validation {
    condition     = var.db_port > 0 && var.db_port <= 65535
    error_message = "db_port precisa estar entre 1 e 65535."
  }
}



# S3
variable "s3_bucket_names" {
  description = "Nomes lógicos dos 3 buckets do pipeline de dados (ex: raw -> trusted -> client)"
  type        = list(string)
  default     = ["raw", "trusted", "client"]

  validation {
    condition     = length(var.s3_bucket_names) == 3
    error_message = "Defina exatamente 3 nomes de bucket."
  }
}

variable "s3_buckets_public" {
  description = "ATENÇÃO: se true, torna os 3 buckets de leitura/escrita públicas (replica o script original). Mantenha false em qualquer ambiente real — dados ficariam abertos para qualquer pessoa na internet."
  type        = bool
  default     = false
}
