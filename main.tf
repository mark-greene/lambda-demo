provider "aws" {
    region = "${var.aws_region}"
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

resource "aws_ssm_parameter" "secret" {
  name  = "${var.environment}/database/password/master"
  type  = "SecureString"
  value = "${var.database_master_password}"
}
