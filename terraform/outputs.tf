output "initiative_reporting_fn_url" {
  value       = aws_lambda_function_url.initiative_reporting_function_url.function_url
  description = "The URL of the initiative reporting lambda function"
}

output "architecture_reporting_lambda_url" {
  value       = aws_lambda_function_url.architecture_reporting_function_url.function_url
  description = "The URL of the architecture-reporting lambda function"
}
