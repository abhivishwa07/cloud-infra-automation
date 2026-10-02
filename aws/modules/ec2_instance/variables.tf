variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}
variable "instance_type" {
  description = "Instance type for the EC2 instance"
  type        = string
  default     = "t2.micro"
}
variable "environment" {
  description = "Deployent environment (e.g,dev,stage,prod)"
  type        = string
  default     = "dev"
}
variable "instnace_name" {
  description = "Name for the EC2 instance"
  type        = string
  default     = "ec2-instance"
}