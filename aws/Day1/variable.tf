

variable "vpc_name" {
  type        = string
  description = "Name of the VPC"
  default     = "AI_project_vpc"

}

variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket"
  default     = "AI_project_bucket"
}