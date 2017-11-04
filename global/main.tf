terraform {
  required_version = ">= 0.10.0"
}

provider "aws" {
    region = "${var.aws_region}"
}

output "region" {
  value = "${var.aws_region}"
}

output "environment" {
  value = "${var.environment}"
}

output "state_bucket" {
  value = "${var.state_bucket}"
}

output "state_bucket_lock" {
  value = "${var.state_bucket_lock}"
}

output "custom_domain" {
  value = "${var.custom_domain}"
}
