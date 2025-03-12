output "jenkins_master_public_ip" {
  value       = aws_instance.jenkins_master.public_ip
  description = "The public IP of the Jenkins master server"
}

output "jenkins_master_public_dns" {
  value       = aws_instance.jenkins_master.public_dns
  description = "The public DNS of the Jenkins master server"
}

output "jenkins_node_public_ip" {
  value       = aws_instance.jenkins_node.public_ip
  description = "The public IP of the Jenkins build node"
}

output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "The DNS name of the load balancer"
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.app.repository_url
  description = "The URL of the ECR repository"
}

output "ecs_cluster_name" {
  value       = aws_ecs_cluster.main.name
  description = "The name of the ECS cluster"
}