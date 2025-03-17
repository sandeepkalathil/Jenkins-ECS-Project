# Jenkins CI/CD Pipeline for AWS ECS Deployment

## Flowchart

```text
+--------------------+
| 1. Create AWS Key |
+--------------------+
        ↓
+--------------------------+
| 2. Set Environment Vars |
+--------------------------+
        ↓
+-------------------+
| 3. IAM Role Setup |
+-------------------+
        ↓
+-------------------+
| 4. Clone Project |
+-------------------+
        ↓
+--------------------+
| 5. Infrastructure |
|    Setup (Terraform) |
+--------------------+
        ↓
+--------------------+
| 6. Jenkins Setup  |
+--------------------+
        ↓
+-------------------------+
| 7. Configure Build Node |
+-------------------------+
        ↓
+----------------------------+
| 8. Configure Credentials |
+----------------------------+
        ↓
+----------------+
| 9. Run Pipeline |
+----------------+
        ↓
+-------------------+
| 10. Verify Deployment |
+-------------------+
```

## 1. Create AWS Key Pair

```bash
aws ec2 create-key-pair --key-name jenkins-node-key --query 'KeyMaterial' --output text > jenkins-node-key.pem
chmod 400 jenkins-node-key.pem
```

## 2. Set Required Environment Variables

```bash
export TF_VAR_key_pair_name="jenkins-node-key"
export TF_VAR_aws_region="eu-north-1"
export TF_VAR_app_environment="production"
```

## 3. Creating IAM Role: MySessionManagerrole

### Step 1: Create the IAM Role

1. Navigate to the AWS Management Console.
2. Open the IAM (Identity and Access Management) service.
3. Select **Roles** from the left-hand menu.
4. Click on **Create Role**.
5. For **Trusted entity type**, select **AWS Service**.
6. Choose **EC2** as the service that will use this role.
7. Click **Next: Permissions**.

### Step 2: Attach Managed Policies

Attach the following managed policies to the role:

- **AmazonEC2ContainerRegistryPowerUser**
  - ARN: `arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser`
- **AmazonSSMManagedInstanceCore**
  - ARN: `arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore`
- **AmazonEC2FullAccess**
  - ARN: `arn:aws:iam::aws:policy/AmazonEC2FullAccess`
- **AmazonECS_FullAccess**
  - ARN: `arn:aws:iam::aws:policy/AmazonECS_FullAccess`

### Step 3: Configure Trust Relationship

1. On the **Review** page, enter the **Role Name** as `MySessionManagerrole`.
2. Add a **Description**: "Allows EC2 instances to call AWS services on your behalf."
3. Click **Create Role**.

### Step 4: Verify the Role

1. Go to the IAM Roles section.
2. Search for `MySessionManagerrole`.
3. Confirm that all the managed policies are attached and the trust relationship is set to allow `ec2.amazonaws.com` to assume the role.

## 4. Clone the Project

```bash
git clone https://github.com/sandeepkalathil/Jenkins-ECS-Project.git
cd Jenkins-ECS-Project/
cd terraform
terraform init
terraform plan
terraform apply
```

## 5. Key Components of the Infrastructure

### Networking (VPC Module):

- Creates a VPC with public and private subnets.
- Configures a single NAT gateway for outbound internet access from private subnets.

### Jenkins Master and Node EC2 Instances:

- Installs Jenkins, Docker, and AWS CLI on the master node.
- Configures the build node with Docker and Java for running builds.
- Security groups allow SSH and Jenkins access (though wide-open ingress rules should be restricted for production).

### ECR for Container Storage:

- Creates an Elastic Container Registry (ECR) for storing Docker images.

### ECS Cluster and Fargate Task Definition:

- Defines an ECS cluster and Fargate-based service.
- Deploys the containerized application with an ALB for load balancing.
- Manages IAM roles and policies for task execution and logging.

### Security and IAM Roles:

- Separate security groups for ALB and ECS tasks.
- IAM role for ECS task execution with access to ECR and CloudWatch logs.

## 6. Jenkins Setup

### Access Jenkins Master

1. Get Jenkins master public IP from Terraform output.
2. Access Jenkins UI: `http://<jenkins_master_public_ip>:8080`
3. Retrieve initial admin password:

```bash
ssh -i jenkins-node-key.pem ubuntu@<jenkins_master_public_ip>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### Configure Jenkins Master

1. Install suggested plugins.
2. Create admin user.
3. Install additional plugins:

- Docker Pipeline
- AWS Credentials
- Blue Ocean

## 7. Configure Jenkins Build Node

1. Navigate to **Manage Jenkins → Manage Nodes**.
2. Add a new node:

- Name: `ec2-build-node`
- Permanent Agent: Yes
- Remote root directory: `/home/ubuntu/jenkins-agent`
- Labels: `ec2-build-node`
- Launch method: Launch agent via SSH
- Host: `<EC2_INSTANCE_PUBLIC_IP>` (from Terraform output)
- Credentials: Add SSH with private key
- Host Key Verification Strategy: Non-verifying

## 8. Configure Jenkins Credentials

1. **AWS Credentials:**

   - Kind: AWS Credentials
   - ID: aws-credentials
   - Description: AWS Credentials
   - Access Key ID: Your AWS access key
   - Secret Access Key: Your AWS secret key

2. **Docker Registry:**

   - Kind: Username with password
   - ID: docker-credentials
   - Description: Docker Registry Credentials
   - Username: AWS
   - Password: (Use AWS CLI get-login-password output)
   - Command to generate password:

   ```bash
   aws ecr get-login-password --region eu-north-1
   ```

3. **GitHub Credentials:**

   - Kind: Username with password
   - ID: github-credentials
   - Description: GitHub Credentials
   - Username: Your GitHub username
   - Password: Your GitHub personal access token

## 9. Pipeline Setup

1. **Create Jenkins Pipeline:**

   - New Item → Pipeline
   - Configure Pipeline:
     - Definition: Pipeline script from SCM
     - SCM: Git
     - Repository URL: Your repository URL
     - Credentials: `github-credentials` (in case of private repo)
     - Branch Specifier: `*/main`
     - Script Path: `Jenkinsfile`

2. **Pipeline Stages:**

- Build and Test
- Docker Image Creation
- Security Scan (Trivy)
- Push to ECR
- Deployment

## 10. Verify the Deployment

1. Verify Docker images in ECR.
2. Check ECS console for active tasks and services.
3. Use ALB DNS to access the website.
4. Confirm website functionality.
5. Jenkins console shows success message.
6. Blue Ocean plugin interface shows pipeline status.

