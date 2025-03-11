provider "aws" {
  region = "eu-north-1"
}

# VPC and Networking
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "task-manager-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-north-1a", "eu-north-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

# Security Groups
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Security group for Jenkins instances"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict to known IPs in production
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Key Pair
resource "aws_key_pair" "sand" {
  key_name   = "sandeep_pub"
  public_key = file("C:/Users/SANDEEP/.ssh/id_rsa.pub")
}

# Jenkins Master Instance
resource "aws_instance" "jenkins_master" {
  ami                  = "ami-09a9858973b288bdd"
  instance_type        = "t3.large"
  key_name             = aws_key_pair.sand.key_name
  subnet_id            = module.vpc.public_subnets[0]
  security_groups      = [aws_security_group.jenkins_sg.id]
  iam_instance_profile = "MySessionManagerrole"

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = base64encode(file("userdata.sh"))

  connection {
    type        = "ssh"
    private_key = file("C:/Users/SANDEEP/.ssh/id_rsa")
    host        = self.public_ip
    user        = "ubuntu"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'The instance is accessible'",
      "sudo apt update",
      "sudo apt install -y openjdk-17-jre",
      "sudo wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key",
      "echo 'deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/' | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null",
      "sudo apt-get update",
      "sudo apt-get install -y jenkins",
      "sudo systemctl start jenkins",
      "sudo systemctl enable jenkins"
    ]
  }

  provisioner "file" {
    source      = "ssh-password-less-Control-Node.sh"
    destination = "/tmp/ssh-password-less-Control-Node.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("C:/Users/SANDEEP/.ssh/id_rsa")
      host        = self.public_ip
    }
  }

  tags = {
    Name = "Jenkins-Master"
  }
}

# Jenkins Docker Node
resource "aws_instance" "jenkins_docker" {
  ami                  = "ami-09a9858973b288bdd"
  instance_type        = "t3.micro"
  key_name             = aws_key_pair.sand.key_name
  subnet_id            = module.vpc.public_subnets[1]
  security_groups      = [aws_security_group.jenkins_sg.id]
  iam_instance_profile = "MySessionManagerrole"

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  user_data = base64encode(file("userdata.sh"))

  connection {
    type        = "ssh"
    private_key = file("C:/Users/SANDEEP/.ssh/id_rsa")
    host        = self.public_ip
    user        = "ubuntu"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'The instance is accessible'",
      "sudo apt update",
      "sudo apt install -y docker.io openjdk-17-jre",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo usermod -aG docker ubuntu",
      "sudo useradd jenkins",
      "sudo usermod -aG docker jenkins",
      "sudo systemctl restart docker"
    ]
  }

  tags = {
    Name = "Jenkins-Docker"
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
  security_groups    = [aws_security_group.jenkins_sg.id]
  subnets            = module.vpc.public_subnets
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
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = "/"
    unhealthy_threshold = "2"
  }
}
