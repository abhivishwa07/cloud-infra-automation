output "instance_id" {
  value       = aws_instance.devops_agent.id
  description = "EC2 Instance ID of the Azure DevOps agent"
}

output "public_ip" {
  value       = aws_instance.devops_agent.public_ip
  description = "Public IP address of the Azure DevOps agent instance"
}

output "private_ip" {
  value       = aws_instance.devops_agent.private_ip
  description = "Private IP address of the Azure DevOps agent instance"
}
