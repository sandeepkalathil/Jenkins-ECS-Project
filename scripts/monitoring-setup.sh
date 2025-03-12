#!/bin/bash

# Setup monitoring for the Task Manager application

# Enable CloudWatch Container Insights
aws ecs update-cluster-settings \
    --cluster task-manager-cluster \
    --settings name=containerInsights,value=enabled \
    --region ${AWS_REGION}

# Create CloudWatch Log Group
aws logs create-log-group \
    --log-group-name "/ecs/task-manager" \
    --region ${AWS_REGION}

# Set log retention
aws logs put-retention-policy \
    --log-group-name "/ecs/task-manager" \
    --retention-in-days 30 \
    --region ${AWS_REGION}

# Create CloudWatch Alarms
aws cloudwatch put-metric-alarm \
    --alarm-name "task-manager-cpu-high" \
    --alarm-description "CPU utilization high" \
    --metric-name CPUUtilization \
    --namespace AWS/ECS \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --dimensions Name=ClusterName,Value=task-manager-cluster Name=ServiceName,Value=task-manager-service \
    --alarm-actions ${SNS_TOPIC_ARN} \
    --region ${AWS_REGION}

aws cloudwatch put-metric-alarm \
    --alarm-name "task-manager-memory-high" \
    --alarm-description "Memory utilization high" \
    --metric-name MemoryUtilization \
    --namespace AWS/ECS \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --dimensions Name=ClusterName,Value=task-manager-cluster Name=ServiceName,Value=task-manager-service \
    --alarm-actions ${SNS_TOPIC_ARN} \
    --region ${AWS_REGION}

# Enable X-Ray tracing
aws ecs update-service \
    --cluster task-manager-cluster \
    --service task-manager-service \
    --enable-execute-command \
    --region ${AWS_REGION}

echo "Monitoring setup completed successfully!"