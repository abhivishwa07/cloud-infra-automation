resource "aws_security_group" "agent_sg" {
  name        = "${var.agent_name}-sg"
  description = "Security Group for Azure DevOps self-hosted agent"

  # Inbound rule for SSH & EC2 Instance Connect
  ingress {
    description = "SSH from anywhere (for EC2 Instance Connect)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rule for all traffic (agent connects outbound to Azure DevOps over HTTPS)
  egress {
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

locals {
  # Template vars shared by both user_data scripts
  template_vars = {
    azp_url       = var.azp_url
    azp_token     = var.azp_token
    azp_pool      = var.azp_pool
    agent_name    = var.agent_name
    agent_version = var.agent_version
  }

  # Choose template based on whether we're using a Packer-baked AMI
  user_data_script = var.use_packer_ami ? templatefile(
    "${path.module}/register-agent.sh.tpl",  # Minimal: registration only (~1 min)
    local.template_vars
  ) : templatefile(
    "${path.module}/user_data.sh.tpl",        # Full: install everything (~15 min)
    local.template_vars
  )
}

resource "aws_instance" "devops_agent" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.agent_sg.id]

  # Root disk for holding Docker images, SDKs, and build artifacts
  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = local.user_data_script

  user_data_replace_on_change = true

  tags = {
    Name        = var.agent_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    AMIMode     = var.use_packer_ami ? "packer-baked" : "full-install"
  }
}
