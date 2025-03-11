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

# Security Group for Jenkins
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-security-group"
  description = "Security group for Jenkins nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict in production
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

# Jenkins Master Instance
resource "aws_instance" "jenkins_master" {
  ami                  = "ami-09a9858973b288bdd"
  instance_type        = "t3.large"
  subnet_id            = module.vpc.public_subnets[0]
  security_groups      = [aws_security_group.jenkins_sg.id]
  iam_instance_profile = "MySessionManagerrole"
  key_name             = "sandeep_pub"

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              set -e
              echo "Starting Jenkins Master setup..."
              sudo apt update
              sudo apt install -y openjdk-17-jre wget curl

              # Add Jenkins repository
              sudo wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
              echo 'deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/' | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
              sudo apt-get update
              sudo apt-get install -y jenkins

              # Start Jenkins
              sudo systemctl enable jenkins
              sudo systemctl start jenkins
              echo "Jenkins Master setup completed!"
              EOF
  )

provisioner "file" {
    source      = "ssh-password-less-Control-Node.sh"
    destination = "/tmp/ssh-password-less-Control-Node.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"  # Adjust based on your AMI (ubuntu, ansadmin, etc.)
      private_key = file("C:/Users/SANDEEP/.ssh/id_rsa")
      host        = self.public_ip
    }
  }
  tags = {
    Name = "Jenkins-Master"
  }
}

# Jenkins Docker Node
resource "aws_instance" "jenkins_docker_node" {
  ami                  = "ami-09a9858973b288bdd"
  instance_type        = "t3.micro"
  subnet_id            = module.vpc.public_subnets[1]
  security_groups      = [aws_security_group.jenkins_sg.id]
  iam_instance_profile = "MySessionManagerrole"
  key_name             = "sandeep_pub"

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              set -e
              echo "Starting Jenkins Docker Node setup..."
              sudo apt update
              sudo apt install -y docker.io openjdk-17-jre

              # Start and enable Docker
              sudo systemctl start docker
              sudo systemctl enable docker

              # Add users to Docker group
              sudo usermod -aG docker ubuntu
              sudo useradd jenkins
              sudo usermod -aG docker jenkins
              sudo systemctl restart docker

              echo "Jenkins Docker Node setup completed!"
              EOF
  )

  tags = {
    Name = "Jenkins-Docker-Node"
  }
}
