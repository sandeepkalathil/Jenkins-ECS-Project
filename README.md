# Task Manager - Implementation Guide

## Architecture Overview

This project implements a complete CI/CD pipeline using:
- Jenkins (Master-Node architecture)
- Docker
- AWS ECS
- Terraform for infrastructure

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI installed and configured
- Terraform installed (v1.0.0+)
- Docker installed

## Infrastructure Setup

### 1. Create AWS Key Pair
```bash
aws ec2 create-key-pair --key-name jenkins-node-key --query 'KeyMaterial' --output text > jenkins-node-key.pem
chmod 400 jenkins-node-key.pem
```

### 2. Set Required Environment Variables
```bash
export TF_VAR_key_pair_name="jenkins-node-key"
export TF_VAR_aws_region="us-east-1"
export TF_VAR_app_environment="production"
```

### 3. Initialize and Apply Terraform
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 4. Infrastructure Components Created
- VPC with public and private subnets
- Jenkins Master EC2 instance
- Jenkins Build Node EC2 instance
- ECR Repository
- ECS Cluster
- Application Load Balancer
- Security Groups
- IAM Roles and Policies

## Jenkins Setup

### 1. Access Jenkins Master
- Get Jenkins master public IP from Terraform output
- Access Jenkins UI: `http://<jenkins_master_public_ip>:8080`
- Get initial admin password:
  ```bash
  ssh -i jenkins-node-key.pem ubuntu@<jenkins_master_public_ip>
  sudo cat /var/lib/jenkins/secrets/initialAdminPassword
  ```

### 2. Configure Jenkins Master
1. Install suggested plugins
2. Create admin user
3. Install additional plugins:
   - Docker Pipeline
   - AWS Pipeline Steps
   - Blue Ocean

### 3. Configure Jenkins Build Node
1. Go to Manage Jenkins → Manage Nodes
2. Add new node:
   - Name: ec2-build-node
   - Permanent Agent: Yes
   - Remote root directory: /home/ubuntu/jenkins-agent
   - Labels: ec2-build-node
   - Launch method: Launch agent via SSH
   - Host: <EC2_INSTANCE_PUBLIC_IP> (from Terraform output)
   - Credentials: Add SSH with private key
   - Host Key Verification Strategy: Non verifying

### 4. Configure Jenkins Credentials
1. AWS Credentials:
   - Kind: AWS Credentials
   - ID: aws-credentials
   - Description: AWS Credentials
   - Access Key ID: Your AWS access key
   - Secret Access Key: Your AWS secret key

2. Docker Registry:
   - Kind: Username with password
   - ID: docker-credentials
   - Description: Docker Registry Credentials
   - Username: AWS
   - Password: (Use AWS CLI get-login-password output)  aws ecr get-login-password --region eu-north-1

3. GitHub:
   - Kind: Username with password
   - ID: github-credentials
   - Add your GitHub credentials

## Pipeline Setup

### 1. Create Jenkins Pipeline
1. New Item → Pipeline
2. Configure Pipeline:
   - Definition: Pipeline script from SCM
   - SCM: Git
   - Repository URL: Your repository URL
   - Credentials: github-credentials
   - Branch Specifier: */main
   - Script Path: Jenkinsfile

### 2. Pipeline Stages
The pipeline includes:
1. Build and Test
   - Runs in Docker container on build node
   - NPM install and build
   - Unit tests
   - Static code analysis
2. Docker Image Creation
   - Builds Docker image
   - Tests image configuration
3. Security Scan (Trivy)
   - Scans for vulnerabilities
4. Push to ECR
   - Authenticates with ECR
   - Pushes image with versioning
5. Deployment
   - Updates ECS service
   - Performs health checks

## ECS Deployment

The deployment is handled automatically by the Jenkins pipeline using:
- Task definition in `ecs/task-definition.json`
- ECS cluster created by Terraform
- Application Load Balancer for routing traffic

### ECS Components
1. Task Definition
   - Container configuration
   - Resource limits
   - Port mappings
   - Health check settings
   - Logging configuration

2. ECS Service
   - Maintains desired task count
   - Handles load balancing
   - Manages task placement
   - Monitors container health

3. Load Balancer
   - Routes traffic to containers
   - Performs health checks
   - Handles SSL/TLS termination
   - Distributes load across tasks

## Monitoring and Maintenance

### 1. Application Monitoring
- CloudWatch Container Insights (enabled by default)
- CloudWatch Logs
- CloudWatch Alarms for CPU and Memory
- X-Ray tracing

### 2. Infrastructure Maintenance
- Regular updates to EC2 instances
- Monitor disk usage on Jenkins nodes
- Review security groups and access policies
- Backup Jenkins configuration
- Monitor ECR image versions
- Regular security scans

### 3. Backup and Disaster Recovery
1. Jenkins Backup:
   - Regular backup of JENKINS_HOME
   - Backup of pipeline configurations
   - Credentials backup

2. Infrastructure Backup:
   - Regular Terraform state backup
   - AMI backups of configured instances
   - Database backups if applicable

## Security Considerations

1. Network Security:
   - VPC configuration with private subnets
   - Security group rules
   - Network ACLs
   - SSL/TLS for all communications

2. Application Security:
   - Regular dependency updates
   - Vulnerability scanning
   - Secret management
   - Access control

3. Infrastructure Security:
   - IAM roles and policies
   - Security group reviews
   - Regular security patches
   - Audit logging

## Troubleshooting

1. Jenkins Issues:
   - Check Jenkins logs: `/var/log/jenkins/jenkins.log`
   - Verify node connectivity
   - Check build node disk space

2. Deployment Issues:
   - Check ECS service events
   - Review task definition
   - Check container logs in CloudWatch
   - Verify ALB health checks

3. Pipeline Issues:
   - Review stage logs in Blue Ocean
   - Check Docker build logs
   - Verify ECR push permissions
   - Check ECS task execution role

## Contact and Support

For issues and support:
1. Check the troubleshooting guide
2. Review CloudWatch logs
3. Check Jenkins build logs
4. Contact the development team

## License

[Your License Information]