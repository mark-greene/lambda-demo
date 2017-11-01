terraform {
  required_version = ">= 0.10.0"
}

module "global" {
  source = "../global"
}

provider "aws" {
    region = "${module.global.region}"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${module.global.state_bucket}"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "${module.global.state_bucket_lock}"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
