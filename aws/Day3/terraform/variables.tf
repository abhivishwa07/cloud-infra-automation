# =============================================================================
# Day3/terraform/variables.tf
# =============================================================================

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "packer_ami_id" {
  type        = string
  description = "AMI ID produced by Packer build (copy from packer-manifest.json)"
  # No default — must be provided after Packer build
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the agent"
  default     = "t2.medium"
}

variable "agent_name" {
  type        = string
  description = "Azure DevOps agent display name"
  default     = "aws-devops-agent-day3"
}

variable "environment" {
  type        = string
  description = "Environment tag"
  default     = "dev"
}

variable "azp_url" {
  type        = string
  description = "Azure DevOps Org URL (e.g. https://dev.azure.com/your-org)"
  default     = "https://dev.azure.com/DevopsRamesh"
}

variable "azp_token" {
  type        = string
  description = "Azure DevOps Personal Access Token (PAT)"
  sensitive   = true
}

variable "azp_pool" {
  type        = string
  description = "Azure DevOps Agent Pool name"
  default     = "aws-agent-pool"
}

variable "nr_api_key" {
  type        = string
  description = "New Relic API Key"
  default     = ""
  sensitive   = true
}

variable "nr_account_id" {
  type        = string
  description = "New Relic Account ID"
  default     = "8563670"
}
