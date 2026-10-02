# =============================================================================
# Day3/packer/agent.pkr.hcl
# Packer template — builds pre-baked Azure DevOps Agent AMI
# Usage:
#   packer init .
#   packer build -var-file="agent.pkrvars.hcl" .
# =============================================================================

packer {
  required_version = ">= 1.9.0"
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# ── Variables ──────────────────────────────────────────────────────────────────
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "agent_version" {
  type        = string
  default     = "5.279.0"
  description = "Azure DevOps agent version to bake into the AMI"
}

variable "base_ami_id" {
  type        = string
  default     = "ami-0b6d9d3d33ba97d99"
  description = "Ubuntu 22.04 LTS base AMI (us-east-1)"
}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
  description = "Build instance type (t3.medium = faster builds)"
}

variable "ami_name_prefix" {
  type    = string
  default = "devops-agent"
}

variable "environment" {
  type    = string
  default = "dev"
}

# ── Source: AWS EBS ────────────────────────────────────────────────────────────
source "amazon-ebs" "devops_agent" {
  region        = var.aws_region
  instance_type = var.instance_type
  source_ami    = var.base_ami_id
  ssh_username  = "ubuntu"

  # Unique AMI name per build using timestamp
  ami_name        = "${var.ami_name_prefix}-v${var.agent_version}-{{timestamp}}"
  ami_description = "Azure DevOps Agent ${var.agent_version} | Java17 Maven Node20 Angular .NET8 Docker AWSCLI AzCLI"

  # Root EBS volume — 30GB gp3
  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # AMI tags
  tags = {
    Name          = "${var.ami_name_prefix}-v${var.agent_version}"
    AgentVersion  = var.agent_version
    BaseAMI       = var.base_ami_id
    OS            = "Ubuntu-22.04"
    ManagedBy     = "Packer"
    Environment   = var.environment
    Tools         = "java17,maven,node20,angular,dotnet8,docker,awscli,azcli"
  }

  snapshot_tags = {
    Name      = "${var.ami_name_prefix}-v${var.agent_version}-snapshot"
    ManagedBy = "Packer"
  }
}

# ── Build ──────────────────────────────────────────────────────────────────────
build {
  name    = "devops-agent-ami"
  sources = ["source.amazon-ebs.devops_agent"]

  # Step 1: Wait for cloud-init on the base instance to finish
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init...'",
      "sudo cloud-init status --wait || true",
      "echo 'Ready to install software.'"
    ]
  }

  # Step 2: Upload and run installation script
  provisioner "shell" {
    script          = "./scripts/install-software.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
    timeout         = "50m"
    environment_vars = [
      "AGENT_VERSION=${var.agent_version}"
    ]
  }

  # Step 3: Final validation
  provisioner "shell" {
    inline = [
      "echo ''",
      "echo '=== FINAL VALIDATION ==='",
      "java -version",
      "mvn --version",
      "node --version",
      "npm --version",
      "dotnet --version",
      "docker --version",
      "aws --version",
      "az --version | head -1",
      "git --version",
      "ls -la /home/ubuntu/myagent/",
      "echo '=== AMI BUILD VALIDATED SUCCESSFULLY ==='"
    ]
  }

  # Step 4: Save AMI ID to manifest file
  post-processor "manifest" {
    output     = "packer-manifest.json"
    strip_path = true
    custom_data = {
      agent_version = var.agent_version
      build_region  = var.aws_region
    }
  }
}
