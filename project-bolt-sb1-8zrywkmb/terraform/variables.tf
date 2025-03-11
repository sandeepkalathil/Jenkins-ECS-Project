variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "task-manager"
}

variable "app_environment" {
  description = "Application environment"
  type        = string
  default     = "production"
}

variable "key_pair_name" {
  description = "Name of the EC2 key pair for Jenkins node"
  type        = string
}

variable "jenkins_master_ip" {
  description = "IP address of Jenkins master"
  type        = string
}