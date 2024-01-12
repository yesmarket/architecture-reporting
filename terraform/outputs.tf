output "initiative_reporting_lambda_url" {
  value       = module.initiative_reporting_lambda.lambda_url
  description = "The URL of the initiative reporting lambda function"
}

output "architecture_reporting_lambda_url" {
  value       = module.architecture_reporting_lambda.lambda_url
  description = "The URL of the architecture-reporting lambda function"
}

output "reverse_proxy_elastic_ip" {
  value       = aws_eip.this.public_ip
  description = "The IP to use for ssh access to the nginx reverse proxy EC2 instance - note: connect using ec2-user@ip"
}

output "reverse_proxy_dns" {
  value       = "http://${aws_instance.reverse_proxy.public_dns}"
  description = "Public DNS for the nginx reverse proxy EC2 instance"
}
