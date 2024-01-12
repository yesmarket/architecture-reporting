variable "aws_access_key" {
  type        = string
  description = "(Required) AWS Access Key"
  sensitive   = true
}

variable "aws_secret_key" {
  type        = string
  description = "(Required) AWS Secret AKey"
  sensitive   = true
}

variable "aws_region" {
  type        = string
  description = "(Optional) AWS region to use for resources"
  default     = "ap-southeast-2"
}

variable "python_runtime" {
  type        = string
  description = "(Optional) Python runtime to use for lambda functions"
  default     = "python3.11"
}

variable "lambda_timeout" {
  type        = number
  description = "(Optional) Lambda function timeout (in seconds)"
  default     = 300
}

variable "initiative_reporting_authorization_header" {
  type        = string
  description = "(Optional) Authorization header for initative-reporting lambda function"
  sensitive   = true
}

variable "architecture_reporting_authorization_header" {
  type        = string
  description = "(Optional) Authorization header for architecture-reporting lambda function"
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

variable "initiative_reporting_confluence_token" {
  type        = string
  description = "(Optional) Basic auth password for Confluence API requests for initiative-reporting"
  sensitive   = true
}

variable "architecture_reporting_confluence_token" {
  type        = string
  description = "(Optional) Basic auth password for Confluence API requests for architecture-reporting"
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

variable "initiative_report_elastic_datastream" {
  type        = string
  description = "(Required) ElasticSearch initative-reporting datastream"
}

variable "architecture_report_elastic_datastream" {
  type        = string
  description = "(Required) ElasticSearch architecture-reporting datastream"
}

variable "initiative_reporting_elastic_api_key" {
  type        = string
  description = "(Optional) ElasticSearch API Key for API requests for initiative-reporting"
  sensitive   = true
}

variable "architecture_reporting_elastic_api_key" {
  type        = string
  description = "(Optional) ElasticSearch API Key for API requests for architecture-reporting"
  sensitive   = true
}

variable "initiative_report_schedule_expression" {
  type        = string
  description = "(Required) CloudWatch schedule expression for the initiative-report"
}

variable "architecture_report_schedule_expression" {
  type        = string
  description = "(Required) CloudWatch schedule expression for the architecture-report"
}

variable "enable_dns_hostnames" {
  type        = bool
  description = "(Optional) Enable DNS hostnames in VPC"
  default     = true
}

variable "vpc_cidr_block" {
  type        = string
  description = "(Optional) Base CIDR Block for VPC"
  default     = "10.0.0.0/16"
}

variable "vpc_public_subnet_cidr_block" {
  type        = string
  description = "(Optional) CIDR Block for Subnet 1 in VPC"
  default     = "10.0.0.0/24"
}

variable "map_public_ip_on_launch" {
  type        = bool
  description = "(Optional) Map a public IP address for Subnet instances"
  default     = true
}

variable "instance_type" {
  type        = string
  description = "(Optional) Type for EC2 Instnace for nginx reverse proxy"
  default     = "t2.micro"
}

variable "reverse_proxy_ansible_playbook_repository" {
  type        = string
  description = "(Required) URL of Absible playbook for nginx reverse proxy"
}

variable "kibana_credentials" {
  type        = string
  description = "(Required) Base64 encoded username:password for basic authentication to Kibana"
  sensitive   = true
}

variable "ssh_public_key" {
  type        = string
  description = "(Required) SSH public key for SSH access to nginx reverse proxy EC2 instancve"
}

variable "reporting_dns_domain" {
  type        = string
  description = "(Required) DNS domain to use for the reverse proxy - need this for certificate registration/renewal with certbot"
}

variable "registered_email_for_domain" {
  type        = string
  description = "(Required) Registered email address for the reverse proxy domain/sub-domain"
}

variable "naming_prefix" {
  type        = string
  description = "Naming prefix for all resources"
  default     = "architecture-reporting"
}

variable "environment" {
  type        = string
  description = "Environment for the resources"
  default     = "dev"
}
