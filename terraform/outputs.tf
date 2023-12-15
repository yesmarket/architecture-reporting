output "initiative_reporting_fn_url" {
  value       = module.initiative_reporting_lambda.lambda_url
  description = "The URL of the initiative reporting lambda function"
}

output "architecture_reporting_lambda_url" {
  value       = module.architecture_reporting_lambda.lambda_url
  description = "The URL of the architecture-reporting lambda function"
}
