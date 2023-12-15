output "lambda_url" {
  value       = aws_lambda_function_url.lambda_function_url.function_url
  description = "The URL of the lambda function"
}
