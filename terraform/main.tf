provider "aws" {
  region = var.aws_region
}

# VPC and Networking
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "task-manager-vpc"
  cidr = "10.0.0.0/16"

  azs = ["${var.aws_region}a", "${var.aws_region}b"]

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

# Jenkins Master EC2 Instance
resource "aws_instance" "jenkins_master" {
  ami           = "ami-09a9858973b288bdd" # Ubuntu 24.04 LTS for eu-north-1
  instance_type = "t3.medium"
  subnet_id     = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.jenkins_master.id]
  key_name              = "jenkins-node-key"
  iam_instance_profile = "MySessionManagerrole"
  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              # Install Java
              apt-get update
              
               # Install required packages
              apt-get update
              apt-get install -y gnupg curl

              # Add the correct Jenkins repository key
              curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
                /usr/share/keyrings/jenkins-keyring.asc > /dev/null

              # Add Jenkins repository
              echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee \
                /etc/apt/sources.list.d/jenkins.list > /dev/null

              # Update package lists again
              apt-get update

              # Install Java and Jenkins
              apt-get install -y openjdk-17-jdk jenkins

              # Enable and start Jenkins service
              systemctl enable jenkins
              systemctl start jenkins

              # Install AWS CLI
              apt-get install -y unzip
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip awscliv2.zip
              ./aws/install

             
              # Install Docker
              apt-get install -y apt-transport-https ca-certificates curl software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
              add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              apt-get update
              apt-get install -y docker-ce docker-ce-cli containerd.io
              usermod -aG docker ubuntu
              usermod -aG docker jenkins

              # Install Docker Compose
              curl -L "https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose
              EOF

  tags = {
    Name = "jenkins-master"
  }
}

# Security Group for Jenkins Master
resource "aws_security_group" "jenkins_master" {
  name        = "jenkins-master-sg"
  description = "Security group for Jenkins master"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Consider restricting to your IP in production
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Consider restricting to your IP in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Jenkins Build Node EC2 Instance
resource "aws_instance" "jenkins_node" {
  ami           = "ami-09a9858973b288bdd" # Ubuntu 24.04 LTS for eu-north-1
  instance_type = "t3.medium"
  subnet_id     = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.jenkins_node.id]
  key_name              = "jenkins-node-key"
  iam_instance_profile = "MySessionManagerrole"
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              # Install Docker
              apt-get update
              apt-get install -y apt-transport-https ca-certificates curl software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
              add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              apt-get update
              apt-get install -y docker-ce docker-ce-cli containerd.io
              usermod -aG docker ubuntu

              # Install Java
              apt-get install -y openjdk-17-jdk

              # Install AWS CLI
              apt-get install -y unzip
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip awscliv2.zip
              ./aws/install

              # Create Jenkins workspace directory
              mkdir -p /home/ubuntu/jenkins-agent
              chown -R ubuntu:ubuntu /home/ubuntu/jenkins-agent
              EOF

  tags = {
    Name = "jenkins-build-node"
  }
}

# Security Group for Jenkins Node
resource "aws_security_group" "jenkins_node" {
  name        = "jenkins-node-sg"
  description = "Security group for Jenkins build node"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECR Repository
resource "aws_ecr_repository" "app" {
  name = "task-manager"
  image_scanning_configuration {
    scan_on_push = true
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "task-manager-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "task-manager-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ALB
resource "aws_lb" "main" {
  name               = "task-manager-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets           = module.vpc.public_subnets
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_target_group" "app" {
  name        = "task-manager-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval           = "30"
    protocol           = "HTTP"
    matcher            = "200"
    timeout            = "3"
    path              = "/"
    unhealthy_threshold = "2"
  }
}

# Security Groups
resource "aws_security_group" "alb" {
  name        = "task-manager-alb-sg"
  description = "ALB Security Group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "task-manager-ecs-tasks-sg"
  description = "ECS Tasks Security Group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_service" "app" {
  name            = "task-manager-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "task-manager"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_task_definition" "app" {
  family                   = "task-manager"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "task-manager"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}

resource "aws_iam_role_policy_attachment" "ecs_task_ecr_access" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ecs_task_cloudwatch_access" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}
