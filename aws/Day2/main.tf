provider "aws" {
  region     = "us-east-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

module "web_server_dev" {
  source        = "../modules/ec2_instance"
  ami_id        = "ami-0b6d9d3d33ba97d99"
  instance_type = "t2.micro"
  environment   = "dev"
  instnace_name = "web-server-dev"
}