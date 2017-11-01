output "secret_read" {
  value = "${data.aws_ssm_parameter.secret_read.value}"
}

output "secret_write" {
  value = "${aws_ssm_parameter.secret_write.value}"
}
