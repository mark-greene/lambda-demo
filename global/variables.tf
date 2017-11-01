variable "aws_region" {
  default = "us-west-1"
}

variable "environment" {
  default = "dev"
}

variable "state_bucket" {
  default = "lambda-demo-terraform-state"
}

variable "state_bucket_lock" {
  default = "lambda-demo-terraform-state-lock"
}
