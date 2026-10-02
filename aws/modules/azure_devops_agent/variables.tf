variable "ami_id" {
  type        = string
  description = "Ubuntu AMI ID for the EC2 Instance"
  default     = "ami-0b6d9d3d33ba97d99" # Ubuntu 22.04 LTS in us-east-1
}

variable "instance_type" {
  type        = string
  description = "EC2 Instance Type"
  default     = "t2.micro"
}

variable "agent_name" {
  type        = string
  description = "Name of the Azure DevOps Agent"
  default     = "aws-ec2-agent"
}

variable "environment" {
  type        = string
  description = "Environment name"
  default     = "dev"
}

variable "azp_url" {
  type        = string
  description = "Azure DevOps Organization URL (e.g. https://dev.azure.com/your-org)"
}

variable "azp_token" {
  type        = string
  description = "Azure DevOps Personal Access Token (PAT)"
  sensitive   = true
}

variable "azp_pool" {
  type        = string
  description = "Azure DevOps Agent Pool Name"
  default     = "Default"
}

variable "agent_version" {
  type        = string
  description = "Azure DevOps Agent version (or 'latest')"
  default     = "5.279.0"
}

variable "use_packer_ami" {
  type        = bool
  description = "If true, uses minimal register-only user_data (assumes Packer AMI with pre-installed tools). If false, runs full installation via user_data."
  default     = false
}
