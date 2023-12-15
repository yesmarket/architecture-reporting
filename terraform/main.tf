##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}

##################################################################################
# RESOURCES
##################################################################################

resource "aws_iam_role" "lambda_iam_role" {
  name               = "reporting-functions"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF

  tags = local.common_tags
}

resource "aws_iam_policy" "lambda_cloudwatch_iam_policy" {
  name        = "lambda_cloudwatch"
  path        = "/"
  description = "IAM policy for cloudwatch logging from a lambda"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*",
            "Effect": "Allow"
        }
    ]
}
EOF

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_iam_role_policy_attachment" {
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = aws_iam_policy.lambda_cloudwatch_iam_policy.arn
}

resource "aws_kms_key" "lambda_env_var_kms_key" {
  description              = "lambda environment variable decryption"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"

  tags = local.common_tags
}

resource "aws_kms_alias" "lambda_env_var_kms_key_alias" {
  name          = "alias/lambda-decryption-key"
  target_key_id = aws_kms_key.lambda_env_var_kms_key.key_id
}

resource "aws_iam_policy" "lambda_kms_iam_policy" {
  name        = "lambda_kms"
  path        = "/"
  description = "IAM policy for decrypting lambda environment variables using a KMS key"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "kms:Decrypt"
            ],
            "Resource": "arn:aws:kms:*:*:*",
            "Effect": "Allow"
        }
    ]
}
EOF

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_kms_iam_role_policy_attachment" {
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = aws_iam_policy.lambda_kms_iam_policy.arn
}

resource "aws_lambda_layer_version" "reporting_dependencies_lambda_layer_version" {
  filename                 = "${path.root}/../code/reporting_dependencies.zip"
  layer_name               = "reporting_dependencies"
  compatible_runtimes      = [var.python_runtime]
  compatible_architectures = ["x86_64"]
}

module "initiative_reporting_lambda" {
  source = "./modules/lambda"

  function_name            = "initiative_reporting"
  function_path            = "${path.root}/../code"
  iam_role_arn             = aws_iam_role.lambda_iam_role.arn
  kms_key_arn              = aws_kms_key.lambda_env_var_kms_key.arn
  lambda_layer_version_arn = aws_lambda_layer_version.reporting_dependencies_lambda_layer_version.arn
  authorization_header     = var.initiative_reporting_authorization_header
  confluence_url           = var.confluence_url
  confluence_email         = var.confluence_email
  confluence_token         = var.initiative_reporting_confluence_token
  confluence_space_id      = var.confluence_space_id
  elastic_url              = var.elastic_url
  elastic_datastream       = var.initiative_report_elastic_datastream
  elastic_api_key          = var.initiative_reporting_elastic_api_key
  elastic_watcher_id       = var.initiative_report_elastic_watcher_id
  schedule_expression      = var.initiative_report_schedule_expression

  common_tags = local.common_tags
}

module "architecture_reporting_lambda" {
  source = "./modules/lambda"

  function_name            = "architecture_reporting"
  function_path            = "${path.root}/../code"
  iam_role_arn             = aws_iam_role.lambda_iam_role.arn
  kms_key_arn              = aws_kms_key.lambda_env_var_kms_key.arn
  lambda_layer_version_arn = aws_lambda_layer_version.reporting_dependencies_lambda_layer_version.arn
  authorization_header     = var.architecture_reporting_authorization_header
  confluence_url           = var.confluence_url
  confluence_email         = var.confluence_email
  confluence_token         = var.architecture_reporting_confluence_token
  confluence_space_id      = var.confluence_space_id
  elastic_url              = var.elastic_url
  elastic_datastream       = var.architecture_report_elastic_datastream
  elastic_api_key          = var.architecture_reporting_elastic_api_key
  elastic_watcher_id       = var.architecture_report_elastic_watcher_id
  schedule_expression      = var.architecture_report_schedule_expression

  common_tags = local.common_tags
}
