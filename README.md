# lambda-demo
Lambda Demo - Terraform

## State
Creates the S3 bucket and the DynamoDB lock table for Remote State.

## Main
API Gateway + Lambda + Custom Domain

Assumes an ACM certificate with the same name as the custom domain in the Virginia region.

Also includes Remote State and Secure Parameters
```
cd state/
AWS_PROFILE=default terraform [get, init, plan, apply]
cd main/
AWS_PROFILE=default terraform [get, init, plan, apply]
```
Outputs the urls to test with `curl`.

## Graph
![](graph.png)
