#!/bin/bash

# Health check script for the Task Manager application

# Configuration
MAX_RETRIES=12
RETRY_INTERVAL=10
TIMEOUT=5

# Get the ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --region ${AWS_REGION} \
    --names task-manager-alb \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

echo "Performing health check on http://${ALB_DNS}/"

# Function to check service health
check_health() {
    curl -sf --max-time ${TIMEOUT} "http://${ALB_DNS}/" > /dev/null
    return $?
}

# Perform health check with retries
for ((i=1; i<=${MAX_RETRIES}; i++)); do
    if check_health; then
        echo "Health check passed on attempt ${i}"
        exit 0
    fi
    
    echo "Health check failed on attempt ${i}/${MAX_RETRIES}"
    
    if [ $i -lt ${MAX_RETRIES} ]; then
        echo "Waiting ${RETRY_INTERVAL} seconds before next attempt..."
        sleep ${RETRY_INTERVAL}
    fi
done

echo "Health check failed after ${MAX_RETRIES} attempts"
exit 1