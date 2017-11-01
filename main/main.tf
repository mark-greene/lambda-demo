// Can not use variables
// terraform.backend: configuration cannot contain interpolations
terraform {
  required_version = ">= 0.10.0"
  backend "s3" {
    bucket          = "lambda-demo-terraform-state"
    key             = "global/s3/terraform.tfstate"
    encrypt         = "true"
    dynamodb_table  = "lambda-demo-terraform-state-lock"
    region = "us-west-1"
  }
}

module "global" {
  source = "../global"
}

provider "aws" {
    region = "${module.global.region}"
}

resource "aws_lambda_function" "lambda_demo" {
    function_name = "lambda_demo"
    handler = "index.handler"
    runtime = "nodejs6.10"
    filename = "function.zip"
    source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}"
    role = "${aws_iam_role.lambda_exec_role.arn}"
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "archive_file" "lambda_zip" {
    type        = "zip"
    source_dir  = "lambda"
    output_path = "function.zip"
}

data "aws_ssm_parameter" "secret_read" {
  name  = "TEST_SECRET"
}

resource "aws_ssm_parameter" "secret_write" {
  name  = "/${module.global.environment}/secret/test"
  type  = "SecureString"
  value = "This is another secret"
}
