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
    description = "Lambda Demo with API Gateway"
    handler = "index.handler"
    runtime = "nodejs6.10"
    filename = "function.zip"
    source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}"
    role = "${aws_iam_role.lambda_exec_role.arn}"
    environment {
       variables {
          TEST = "${data.aws_ssm_parameter.secret_read.value}"
       }
    }
    publish = true
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"
  assume_role_policy = "${file("policies/lambda-role.json")}"
}

data "archive_file" "lambda_zip" {
    type        = "zip"
    source_dir  = "lambda"
    output_path = "function.zip"
}

resource "aws_api_gateway_rest_api" "lambda_demo_api" {
  name = "lambda_demo_api"
  description = "Lambda Demo Rest Api"
}

resource "aws_api_gateway_resource" "lambda_demo_api_resource" {
  rest_api_id = "${aws_api_gateway_rest_api.lambda_demo_api.id}"
  parent_id = "${aws_api_gateway_rest_api.lambda_demo_api.root_resource_id}"
  path_part = "messages"
}

resource "aws_api_gateway_method" "lambda_demo_api_method" {
  rest_api_id = "${aws_api_gateway_rest_api.lambda_demo_api.id}"
  resource_id = "${aws_api_gateway_resource.lambda_demo_api_resource.id}"
  http_method = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "200" {
  rest_api_id = "${aws_api_gateway_rest_api.lambda_demo_api.id}"
  resource_id = "${aws_api_gateway_resource.lambda_demo_api_resource.id}"
  http_method = "${aws_api_gateway_method.lambda_demo_api_method.http_method}"
  status_code = "200"
  response_models = { "application/json" = "Empty" }
}

resource "aws_api_gateway_integration" "lambda_demo_api_method-integration" {
  rest_api_id = "${aws_api_gateway_rest_api.lambda_demo_api.id}"
  resource_id = "${aws_api_gateway_resource.lambda_demo_api_resource.id}"
  http_method = "${aws_api_gateway_method.lambda_demo_api_method.http_method}"
  type = "AWS_PROXY"
  uri = "arn:aws:apigateway:${module.global.region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${module.global.region}:${data.aws_caller_identity.current.account_id}:function:${aws_lambda_function.lambda_demo.function_name}/invocations"
  integration_http_method = "POST"
}

resource "aws_api_gateway_integration_response" "lambda_demo_api_integration-response" {
    depends_on = [
      "aws_api_gateway_method.lambda_demo_api_method",
      "aws_api_gateway_integration.lambda_demo_api_method-integration"
    ]
   rest_api_id = "${aws_api_gateway_rest_api.lambda_demo_api.id}"
   resource_id = "${aws_api_gateway_resource.lambda_demo_api_resource.id}"
   http_method = "${aws_api_gateway_method.lambda_demo_api_method.http_method}"
   status_code = "${aws_api_gateway_method_response.200.status_code}"

   response_templates = { "application/json" = "" }
}

resource "aws_lambda_permission" "allow_api_gateway" {
    function_name = "${aws_lambda_function.lambda_demo.function_name}"
    statement_id = "AllowExecutionFromApiGateway"
    action = "lambda:InvokeFunction"
    principal = "apigateway.amazonaws.com"
    source_arn = "arn:aws:execute-api:${module.global.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.lambda_demo_api.id}/*/${aws_api_gateway_method.lambda_demo_api_method.http_method}${aws_api_gateway_resource.lambda_demo_api_resource.path}"
}

resource "aws_api_gateway_deployment" "lambda_demo_deployment_dev" {
  depends_on = [
    "aws_api_gateway_method.lambda_demo_api_method",
    "aws_api_gateway_integration.lambda_demo_api_method-integration"
  ]
  rest_api_id = "${aws_api_gateway_rest_api.lambda_demo_api.id}"
  stage_name = "dev"

  variables {
      deployed_at = "${timestamp()}"
  }
}

resource "aws_api_gateway_deployment" "lambda_demo_deployment_prod" {
  depends_on = [
    "aws_api_gateway_method.lambda_demo_api_method",
    "aws_api_gateway_integration.lambda_demo_api_method-integration"
  ]
  rest_api_id = "${aws_api_gateway_rest_api.lambda_demo_api.id}"
  stage_name = "api"

  variables {
      deployed_at = "${timestamp()}"
  }
}

resource "aws_api_gateway_base_path_mapping" "lambda_demo" {
  api_id                       = "${aws_api_gateway_rest_api.lambda_demo_api.id}"
  stage_name                   = "${aws_api_gateway_deployment.lambda_demo_deployment_prod.stage_name}"
  domain_name                  = "${aws_api_gateway_domain_name.lambda_demo.domain_name}"
  base_path                    = "${aws_api_gateway_resource.lambda_demo_api_resource.path_part}"
}

resource "aws_api_gateway_domain_name" "lambda_demo" {
  domain_name                 = "api.devops.onelxk.co"
  certificate_arn             = "${data.aws_acm_certificate.lambda_demo.arn}"
}

provider "aws" {
  alias = "virginia"
  region = "us-east-1"
}

data "aws_acm_certificate" "lambda_demo" {
  domain   = "devops.onelxk.co"
  statuses = ["ISSUED"]
  provider = "aws.virginia"
}

data "aws_route53_zone" "lambda_demo" {
  name = "devops.onelxk.co"
}

resource "aws_route53_record" "lambda_demo" {
  zone_id                     = "${data.aws_route53_zone.lambda_demo.id}"
  name                        = "${aws_api_gateway_domain_name.lambda_demo.domain_name}"
  type                        = "A"
  alias {
    name                      = "${aws_api_gateway_domain_name.lambda_demo.cloudfront_domain_name}"
    zone_id                   = "${aws_api_gateway_domain_name.lambda_demo.cloudfront_zone_id}"
    evaluate_target_health    = true
  }
}

output "dev_url" {
  value = "https://${aws_api_gateway_deployment.lambda_demo_deployment_dev.rest_api_id}.execute-api.${module.global.region}.amazonaws.com/${aws_api_gateway_deployment.lambda_demo_deployment_dev.stage_name}"
}

output "prod_url" {
  value = "https://${aws_api_gateway_deployment.lambda_demo_deployment_prod.rest_api_id}.execute-api.${module.global.region}.amazonaws.com/${aws_api_gateway_deployment.lambda_demo_deployment_prod.stage_name}"
}

data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "secret_read" {
  name  = "TEST_SECRET"
}

resource "aws_ssm_parameter" "secret_write" {
  name  = "/${module.global.environment}/secret/test"
  type  = "SecureString"
  value = "This is another secret"
}
