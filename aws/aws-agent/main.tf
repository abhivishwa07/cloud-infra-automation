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

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "azp_url" {
  type        = string
  description = "Azure DevOps Org URL"
  default = "https://dev.azure.com/DevopsRamesh"
}

variable "azp_token" {
  type        = string
  description = "Azure DevOps Personal Access Token"
  sensitive   = true
}

variable "azp_pool" {
  type        = string
  description = "Azure DevOps Agent Pool Name"
  default     = "aws-agent-pool"
}

variable "agent_name" {
  type    = string
  default = "aws-devops-agent-01"
}

module "azure_devops_agent" {
  source        = "../modules/azure_devops_agent"
  ami_id        = "ami-0b6d9d3d33ba97d99" # Ubuntu 22.04 LTS
  instance_type = "t2.medium"
  environment   = "dev"
  agent_name    = var.agent_name
  azp_url       = var.azp_url
  azp_token     = var.azp_token
  azp_pool      = var.azp_pool
}

output "agent_instance_id" {
  value = module.azure_devops_agent.instance_id
}

output "agent_public_ip" {
  value = module.azure_devops_agent.public_ip
}
