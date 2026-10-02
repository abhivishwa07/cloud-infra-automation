# =============================================================================
# Day3/terraform/main.tf
# Deploys an Azure DevOps Agent EC2 instance from a Packer-baked AMI.
# Agent registration happens via minimal user_data (< 1 min boot time).
# =============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ── Security Group ─────────────────────────────────────────────────────────────
resource "aws_security_group" "agent_sg" {
  name        = "${var.agent_name}-sg"
  description = "Security Group for Azure DevOps self-hosted agent"

  ingress {
    description = "SSH / EC2 Instance Connect"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound (agent reaches Azure DevOps over HTTPS)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.agent_name}-sg"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ── EC2 Instance from Packer AMI ───────────────────────────────────────────────
resource "aws_instance" "devops_agent" {
  ami           = var.packer_ami_id   # ← Pre-baked AMI from Packer
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.agent_sg.id]

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # Minimal user_data: only registers the agent (~30 seconds)
  user_data = templatefile("${path.module}/register-agent.sh.tpl", {
    azp_url       = var.azp_url
    azp_token     = var.azp_token
    azp_pool      = var.azp_pool
    agent_name    = var.agent_name
    nr_api_key    = var.nr_api_key
    nr_account_id = var.nr_account_id
  })

  user_data_replace_on_change = true

  tags = {
    Name         = var.agent_name
    Environment  = var.environment
    ManagedBy    = "Terraform"
    PackerAMI    = var.packer_ami_id
    AgentPool    = var.azp_pool
  }
}

# ── Outputs ────────────────────────────────────────────────────────────────────
output "agent_instance_id" {
  description = "EC2 Instance ID of the DevOps agent"
  value       = aws_instance.devops_agent.id
}

output "agent_public_ip" {
  description = "Public IP of the DevOps agent"
  value       = aws_instance.devops_agent.public_ip
}

output "agent_name" {
  description = "Azure DevOps agent name"
  value       = var.agent_name
}

output "agent_pool" {
  description = "Azure DevOps agent pool"
  value       = var.azp_pool
}
