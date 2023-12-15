variable "aws_access_key" {
  type        = string
  description = "AWS Access Key"
  sensitive   = true
}

variable "aws_secret_key" {
  type        = string
  description = "AWS Secret AKey"
  sensitive   = true
}

variable "aws_region" {
  type        = string
  description = "AWS region to use for resources"
  default     = "ap-southeast-2"
}

#variable "billing_code" {
#    type = string
#    description = "Billing code for resource tagging"
#}

variable "python_runtime_target" {
  type        = string
  description = "Python runtime to use for lambda functions"
  default     = "python3.11"
}

variable "lambda_timeout" {
  type        = number
  description = "Lambda function timeout (in seconds)"
  default     = 300
}

variable "lambda_authorization_header" {
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

variable "confluence_arc_tag" {
  type        = string
  description = "Confluence tag for ARC items"
  default     = "arc_item"
}

variable "confluence_da_tag" {
  type        = string
  description = "Confluence tag for DA items"
  default     = "da_item"
}

variable "confluence_initiative_tag" {
  type        = string
  description = "Confluence tag for initiative pages"
  default     = "initiative"
}

variable "elastic_url" {
  type        = string
  description = "ElasticSearch base URL"
}

variable "initiative_report_elastic_datastream" {
  type        = string
  description = "ElasticSearch initative-reporting datastream"
}

variable "architecture_report_elastic_datastream" {
  type        = string
  description = "ElasticSearch architecture-reporting datastream"
}

variable "elastic_api_key" {
  type        = string
  description = "ElasticSearch API Key for API requests"
  sensitive   = true
}

variable "initiative_report_elastic_watcher_id" {
  type        = string
  description = "ElasticSearch initiative-reporting watcher ID"
}

variable "architecture_report_elastic_watcher_id" {
  type        = string
  description = "ElasticSearch architecture-reporting watcher ID"
}

variable "initiative_report_schedule_expression" {
  type        = string
  description = "CloudWatch schedule expression for the initiative-report"
}

variable "architecture_report_schedule_expression" {
  type        = string
  description = "CloudWatch schedule expression for the architecture-report"
}
