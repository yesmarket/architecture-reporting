variable "function_name" {
  type        = string
  description = "Name of the lambda function"
}

variable "function_path" {
  type        = string
  description = "Path to the function code file"
}

variable "iam_role_arn" {
  type        = string
  description = "ARN of lambda function IAM role"
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of KMS key used by lambda function to decrypt encrypted environment variables"
}

variable "lambda_layer_version_arn" {
  type        = string
  description = "ARN of lambda layer version that contains the python dependencies required by the lambda function"
}

variable "runtime" {
  type        = string
  description = "Runtime to use for lambda functions"
  default     = "python3.11"
}

variable "timeout" {
  type        = number
  description = "Lambda function timeout (in seconds)"
  default     = 300
}

variable "authorization_header" {
  type        = string
  description = "Authorization header to pass to lambda functions"
  sensitive   = true
}

variable "confluence_url" {
  type        = string
  description = "Confluence URL"
}

variable "confluence_email" {
  type        = string
  description = "Basic auth username for Confluence API requests"
}

variable "confluence_token" {
  type        = string
  description = "Basic auth password for Confluence API requests"
  sensitive   = true
}

variable "confluence_space_id" {
  type        = string
  description = "Confluence space ID to search for pages"
}

variable "elastic_url" {
  type        = string
  description = "ElasticSearch base URL"
}

variable "elastic_datastream" {
  type        = string
  description = "ElasticSearch datastream"
}

variable "elastic_api_key" {
  type        = string
  description = "ElasticSearch API Key for API requests"
  sensitive   = true
}

variable "schedule_expression" {
  type        = string
  description = "CloudWatch schedule expression"
}

variable "common_tags" {
  type        = map(string)
  description = "Map of tags to be applied to all resources"
  default     = {}
}
