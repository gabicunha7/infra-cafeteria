# Infra Cafeteria - LocalStack (script bash, sem Terraform)

Recria a mesma infraestrutura do `terraform/` direto via AWS CLI apontando
para o LocalStack (emulador local da AWS) - sem depender da conta AWS
Academy, sem SCP bloqueando nada, sem gastar credito de lab.

Não usa Terraform de propósito: são dois scripts bash que chamam o AWS CLI
diretamente (`create_infra.sh` / `destroy_infra.sh`), guardando os IDs
criados num arquivo local (`.ids.env`) para saber o que destruir depois.

## O que e criado

VPC, 6 subnets (2 publicas + 4 privadas), Internet Gateway, NAT Gateway
(melhor esforço - depende do suporte do LocalStack), 2 route tables,
7 security groups, par de chaves, 6 "instancias" EC2 (front-a/b,
backend-a/b, db, messaging-b), 2 Application Load Balancers (publico e
interno) com target groups e listeners, e 3 buckets S3 (raw/trusted/client)
com versionamento, criptografia e bloqueio de acesso publico.

**Nao incluido:** EFS (so existe no plano pago "Ultimate" do LocalStack).

## Limitacao importante: sem maquina real

O LocalStack nao roda um sistema operacional de verdade atras das
"instancias" EC2 (isso vale em qualquer plano, ate no pago). O Terraform/
scripts criam os recursos normalmente, mas nao ha SSH, nao ha Docker, nao
ha nada rodando de verdade atras dos IDs de instancia. **Os scripts do
Ansible (`../ansible/`) nao funcionam contra essa infra.**

O que funciona de verdade: os buckets S3 (dá pra gravar/ler arquivos
normalmente) e as respostas da API de EC2/ELB (describe, IDs, tags, etc.)
para fins de teste/demonstracao do desenho da infra.

## Como usar

### 1. Conta gratuita no LocalStack (obrigatorio desde marco de 2026)

Cria uma conta gratuita em https://app.localstack.cloud, pega o "Auth
Token" no painel, e exporta:

```bash
export LOCALSTACK_AUTH_TOKEN=seu_token_aqui
```

### 2. Sobe o LocalStack

```bash
docker compose up -d
curl http://localhost:4566/_localstack/health
```

### 3. Pre-requisitos do script

Precisa de `aws` cli e `jq` instalados:

```bash
sudo apt install -y awscli jq
```

### 4. Cria a infra

```bash
./create_infra.sh
```

Isso vai imprimir o progresso de cada recurso e, no final, o DNS dos dois
ALBs. Os IDs de tudo que foi criado ficam salvos em `.ids.env` (nao
commitar - ja esta no `.gitignore`).

### 5. Conferir o que foi criado

```bash
source ./config.sh
awsl s3api list-buckets
awsl ec2 describe-instances --query 'Reservations[].Instances[].{Id:InstanceId,Name:Tags[?Key==`Name`]|[0].Value,State:State.Name}'
awsl elbv2 describe-load-balancers --query 'LoadBalancers[].{Name:LoadBalancerName,DNS:DNSName}'
```

### 6. Destruir tudo

```bash
./destroy_infra.sh
```

Le o `.ids.env`, apaga tudo na ordem certa (buckets, ALBs, instancias,
security groups, subnets, VPC), e remove o `.ids.env` no final.

```bash
docker compose down
```
