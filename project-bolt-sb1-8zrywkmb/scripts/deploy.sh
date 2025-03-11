#!/bin/bash

# Check if AWS credentials are set
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "AWS credentials not set. Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
    exit 1
fi

# Build the application
echo "Building application..."
npm run build

# Build Docker image
echo "Building Docker image..."
docker build -t task-manager .

# Push to ECR
echo "Pushing to ECR..."
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPOSITORY
docker tag task-manager:latest $ECR_REPOSITORY/task-manager:latest
docker push $ECR_REPOSITORY/task-manager:latest

# Update ECS service
echo "Updating ECS service..."
aws ecs update-service \
    --cluster task-manager-cluster \
    --service task-manager-service \
    --force-new-deployment

echo "Deployment completed successfully!"