#!/bin/bash

REGION="us-east-1"
EMAIL="gabriela.cunha@sptech.school"

# SNS
TOPIC_ARN=$(aws sns create-topic --name AlertaInfra --region $REGION --query 'TopicArn' --output text 2>/dev/null)
aws sns subscribe --topic-arn $TOPIC_ARN --protocol email --notification-endpoint $EMAIL --region $REGION >/dev/null 2>&1

# EC2
INSTANCE_IDS=$(aws ec2 describe-instances --region $REGION \
  --filters "Name=tag:Name,Values=ec2-publica-front-f1,ec2-publica-front-f2,ec2-privada-back" \
  --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0]]' --output text)

# EFS
EFS_ID=$(aws efs describe-file-systems --region $REGION --query 'FileSystems[0].FileSystemId' --output text 2>/dev/null)

# ALB
ALB_NAME=$(aws elbv2 describe-load-balancers --names alb-cafeteria --region $REGION \
  --query 'LoadBalancers[0].LoadBalancerName' --output text 2>/dev/null)
ALB_ARN=$(aws elbv2 describe-load-balancers --names alb-cafeteria --region $REGION \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null)
TG_ARN=$(aws elbv2 describe-target-groups --names tg-cafeteria --region $REGION \
  --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)

echo "criando alarmes"

# 1-3: CPU por instância 60%
FRONT1_ID=$(echo "$INSTANCE_IDS" | grep front-f1 | awk '{print $1}')
aws cloudwatch put-metric-alarm --alarm-name "1-CPU-Front1-Alto" --metric-name CPUUtilization \
  --namespace AWS/EC2 --statistic Average --period 300 --threshold 60 \
  --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=$FRONT1_ID \
  --evaluation-periods 2 --alarm-actions $TOPIC_ARN --region $REGION >/dev/null 2>&1

FRONT2_ID=$(echo "$INSTANCE_IDS" | grep front-f2 | awk '{print $1}')
aws cloudwatch put-metric-alarm --alarm-name "2-CPU-Front2-Alto" --metric-name CPUUtilization \
  --namespace AWS/EC2 --statistic Average --period 300 --threshold 60 \
  --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=$FRONT2_ID \
  --evaluation-periods 2 --alarm-actions $TOPIC_ARN --region $REGION >/dev/null 2>&1

BACK_ID=$(echo "$INSTANCE_IDS" | grep privada-back | awk '{print $1}')
aws cloudwatch put-metric-alarm --alarm-name "3-CPU-Backend-Alto" --metric-name CPUUtilization \
  --namespace AWS/EC2 --statistic Average --period 300 --threshold 60 \
  --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=$BACK_ID \
  --evaluation-periods 2 --alarm-actions $TOPIC_ARN --region $REGION >/dev/null 2>&1

# 4: Status Check 
aws cloudwatch put-metric-alarm --alarm-name "4a-StatusCheck-Front1" --metric-name StatusCheckFailed \
  --namespace AWS/EC2 --statistic Maximum --period 60 --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold --dimensions Name=InstanceId,Value=$FRONT1_ID \
  --evaluation-periods 1 --alarm-actions $TOPIC_ARN --region $REGION >/dev/null 2>&1

aws cloudwatch put-metric-alarm --alarm-name "4b-StatusCheck-Front2" --metric-name StatusCheckFailed \
  --namespace AWS/EC2 --statistic Maximum --period 60 --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold --dimensions Name=InstanceId,Value=$FRONT2_ID \
  --evaluation-periods 1 --alarm-actions $TOPIC_ARN --region $REGION >/dev/null 2>&1

aws cloudwatch put-metric-alarm --alarm-name "4c-StatusCheck-Backend" --metric-name StatusCheckFailed \
  --namespace AWS/EC2 --statistic Maximum --period 60 --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold --dimensions Name=InstanceId,Value=$BACK_ID \
  --evaluation-periods 1 --alarm-actions $TOPIC_ARN --region $REGION >/dev/null 2>&1

# 5-6: Network 300MB 
aws cloudwatch put-metric-alarm --alarm-name "5-NetworkIn-Alto" --metric-name NetworkIn \
  --namespace AWS/EC2 --statistic Sum --period 300 --threshold 300000000 \
  --comparison-operator GreaterThanThreshold --evaluation-periods 2 \
  --alarm-actions $TOPIC_ARN --region $REGION >/dev/null 2>&1

aws cloudwatch put-metric-alarm --alarm-name "6-NetworkOut-Alto" --metric-name NetworkOut \
  --namespace AWS/EC2 --statistic Sum --period 300 --threshold 300000000 \
  --comparison-operator GreaterThanThreshold --evaluation-periods 2 \
  --alarm-actions $TOPIC_ARN --region $REGION >/dev/null 2>&1

# 7: EFS Burst Credits
aws cloudwatch put-metric-alarm --alarm-name "7-EFS-Credits-Baixo" --metric-name BurstCreditBalance \
  --namespace AWS/EFS --statistic Minimum --period 300 --threshold 1000000000 \
  --comparison-operator LessThanThreshold --dimensions Name=FileSystemId,Value=$EFS_ID \
  --evaluation-periods 2 --alarm-actions $TOPIC_ARN --region $REGION >/dev/null 2>&1

# 8: ALB 5XX 
aws cloudwatch put-metric-alarm --alarm-name "8-ALB-Erro5XX" --metric-name HTTPCode_Target_5XX_Count \
  --namespace AWS/ApplicationELB --statistic Sum --period 60 --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold --dimensions Name=LoadBalancer,Value=$ALB_NAME \
  --evaluation-periods 1 --alarm-actions $TOPIC_ARN --region $REGION >/dev/null 2>&1

# 9: ALB Target Unhealthy
aws cloudwatch put-metric-alarm --alarm-name "9-ALB-Target-Unhealthy" --metric-name UnHealthyHostCount \
  --namespace AWS/ApplicationELB --statistic Maximum --period 60 --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold --dimensions Name=LoadBalancer,Value=$ALB_NAME \
  --evaluation-periods 1 --alarm-actions $TOPIC_ARN --region $REGION >/dev/null 2>&1

# > 100 requests em 5 min
aws cloudwatch put-metric-alarm --alarm-name "10-ALB-Requests-Alto" --metric-name RequestCount \
  --namespace AWS/ApplicationELB --statistic Sum --period 300 --threshold 100 \
  --comparison-operator GreaterThanThreshold --dimensions Name=LoadBalancer,Value=$ALB_NAME \
  --evaluation-periods 1 --alarm-actions $TOPIC_ARN --region $REGION >/dev/null 2>&1
echo "alarmes criados"

echo "criando DASH"
# EC2 CPU 
EC2_CPU="[\"AWS/EC2\",\"CPUUtilization\",\"InstanceId\",\"$FRONT1_ID\"],[\"AWS/EC2\",\"CPUUtilization\",\"InstanceId\",\"$FRONT2_ID\"],[\"AWS/EC2\",\"CPUUtilization\",\"InstanceId\",\"$BACK_ID\"]"

# EC2 Network In (sempre tem dados)
EC2_NET_IN="[\"AWS/EC2\",\"NetworkIn\",\"InstanceId\",\"$FRONT1_ID\"],[\"AWS/EC2\",\"NetworkIn\",\"InstanceId\",\"$FRONT2_ID\"],[\"AWS/EC2\",\"NetworkIn\",\"InstanceId\",\"$BACK_ID\"]"

# EC2 Network Out 
EC2_NET_OUT="[\"AWS/EC2\",\"NetworkOut\",\"InstanceId\",\"$FRONT1_ID\"],[\"AWS/EC2\",\"NetworkOut\",\"InstanceId\",\"$FRONT2_ID\"],[\"AWS/EC2\",\"NetworkOut\",\"InstanceId\",\"$BACK_ID\"]"

# EFS 
EFS_BURST="[\"AWS/EFS\",\"BurstCreditBalance\",\"FileSystemId\",\"$EFS_ID\"]"

DASHBOARD_BODY='{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": ['"$EC2_CPU"'],
        "title": "EC2 CPU (%)",
        "region": "'"$REGION"'",
        "period": 300,
        "stat": "Average",
        "yAxis": {"left": {"min": 0, "max": 100}}
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": ['"$EC2_NET_IN"'],
        "title": "Network In (Bytes)",
        "region": "'"$REGION"'",
        "period": 300,
        "stat": "Sum"
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": ['"$EC2_NET_OUT"'],
        "title": "Network Out (Bytes)",
        "region": "'"$REGION"'",
        "period": 300,
        "stat": "Sum"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": ['"$EFS_BURST"'],
        "title": "EFS Burst Credits",
        "region": "'"$REGION"'",
        "period": 300,
        "stat": "Average"
      }
    }
  ]
}'

aws cloudwatch put-dashboard --dashboard-name "InfraCafeteria-Dev" --dashboard-body "$DASHBOARD_BODY" --region $REGION

echo "dahs criada"

echo "FINALIZOU...alarmes criados:"
echo "CPU > 60%"
echo "check status"
echo "ntw in > 300MB"
echo "ntw out > 300MB"
echo "EFS creditos < 1GB"
echo "ALB erros 5XX > 0"
echo "ALB Unhealthy"
echo "ALB Requests > 100 em 5min"