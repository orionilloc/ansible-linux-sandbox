#variables.tf

variable "aws_region" {
  description = "The AWS region to deploy resources into."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile to use for authentication (e.g., 'stamper')."
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "The instance type to use for all nodes."
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "The name of the SSH key pair created in AWS."
  type        = string
  default     = "ansible-lab-key"
}

variable "project_name" {
  description = "Project name tag prefix for resources."
  type        = string
  default     = "ansible-lab"
}