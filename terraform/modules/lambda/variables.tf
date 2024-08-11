variable "function_name" {
  type        = string
  description = "(Required) Name of the lambda function"
}

variable "function_path" {
  type        = string
  description = "(Required) Path to the function code file"
}

variable "iam_role_arn" {
  type        = string
  description = "(Required) ARN of lambda function IAM role"
}

variable "kms_key_id" {
  type        = string
  description = "(Required) ID of KMS key used by lambda function to decrypt encrypted environment variables"
}

variable "kms_key_arn" {
  type        = string
  description = "(Required) ARN of KMS key used by lambda function to decrypt encrypted environment variables"
}

variable "lambda_layer_version_arn" {
  type        = string
  description = "(Required) ARN of lambda layer version that contains the python dependencies required by the lambda function"
}

variable "runtime" {
  type        = string
  description = "(Optional) Runtime to use for lambda functions"
  default     = "python3.11"
}

variable "timeout" {
  type        = number
  description = "(Optional) Lambda function timeout (in seconds)"
  default     = 300
}

variable "environment_variable_encryption" {
  type        = string
  description = "(Optional) Whether to encrypt sensitive environment variables in lambda"
  default     = "True"
}

variable "authorization_header" {
  type        = string
  description = "(Required) Authorization header to pass to lambda functions"
  sensitive   = true
}

variable "confluence_url" {
  type        = string
  description = "(Required) Confluence URL"
}

variable "confluence_email" {
  type        = string
  description = "(Required) Basic auth username for Confluence API requests"
}

variable "confluence_token" {
  type        = string
  description = "(Required) Basic auth password for Confluence API requests"
  sensitive   = true
}

variable "confluence_space_id" {
  type        = string
  description = "(Required) Confluence space ID to search for pages"
}

variable "elastic_url" {
  type        = string
  description = "(Required) ElasticSearch base URL"
}

variable "elastic_datastream" {
  type        = string
  description = "(Required) ElasticSearch datastream"
}

variable "elastic_api_key" {
  type        = string
  description = "(Required) ElasticSearch API Key for API requests"
  sensitive   = true
}

variable "schedule_expression" {
  type        = string
  description = "(Required) CloudWatch schedule expression"
}

variable "common_tags" {
  type        = map(string)
  description = "(Optional) Map of tags to be applied to all resources"
  default     = {}
}

variable "naming_prefix" {
  type        = string
  description = "(Required) Naming prefix for all resources"
}
