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
  filename                 = "${path.module}/code/reporting_dependencies.zip"
  layer_name               = "reporting_dependencies"
  compatible_runtimes      = [var.python_runtime_target]
  compatible_architectures = ["x86_64"]
}

data "archive_file" "initiative_reporting_code" {
  type        = "zip"
  source_file = "${path.module}/code/initiative_reporting.py"
  output_path = "initiative_reporting.zip"
}

resource "aws_lambda_function" "initiative_reporting_function" {
  function_name    = "initiative_reporting"
  filename         = "initiative_reporting.zip"
  source_code_hash = data.archive_file.initiative_reporting_code.output_base64sha256
  role             = aws_iam_role.lambda_iam_role.arn
  runtime          = var.python_runtime_target
  handler          = "initiative_reporting.lambda_handler"
  timeout          = var.lambda_timeout
  kms_key_arn      = aws_kms_key.lambda_env_var_kms_key.arn

  environment {
    variables = {
      AUTHORIZATION_HEADER = var.lambda_authorization_header
      CONFLUENCE_URL       = var.confluence_url
      CONFLUENCE_EMAIL     = var.confluence_email
      CONFLUENCE_TOKEN     = var.confluence_token
      CONFLUENCE_SPACE_ID  = var.confluence_space_id
      CONFLUENCE_TAG       = var.confluence_initiative_tag
      ELASTIC_URL          = var.elastic_url
      ELASTIC_DATASTREAM   = var.initiative_report_elastic_datastream
      ELASTIC_API_KEY      = var.elastic_api_key
      ELASTIC_WATCHER_ID   = var.initiative_report_elastic_watcher_id
    }
  }

  layers = [aws_lambda_layer_version.reporting_dependencies_lambda_layer_version.arn, "arn:aws:lambda:ap-southeast-2:336392948345:layer:AWSSDKPandas-Python311:2"]

  tags = local.common_tags
}

resource "aws_lambda_function_url" "initiative_reporting_function_url" {
  function_name      = aws_lambda_function.initiative_reporting_function.function_name
  authorization_type = "NONE"
}

resource "aws_cloudwatch_event_rule" "initiative_reporting_cloudwatch_event_rule" {
  name                = "run_initiative_reporting_function"
  description         = "Schedule initiative_reporting lambda function"
  schedule_expression = var.initiative_report_schedule_expression

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "initiative_reporting_cloudwatch_event_target" {
  target_id = "lambda-function-target"
  rule      = aws_cloudwatch_event_rule.initiative_reporting_cloudwatch_event_rule.name
  arn       = aws_lambda_function.initiative_reporting_function.arn
}

resource "aws_lambda_permission" "allow_initiative_reporting_execution_from_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.initiative_reporting_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.initiative_reporting_cloudwatch_event_rule.arn
}
data "archive_file" "architecture_reporting_code" {
  type        = "zip"
  source_file = "${path.module}/code/architecture_reporting.py"
  output_path = "architecture_reporting.zip"
}

resource "aws_lambda_function" "architecture_reporting_function" {
  function_name    = "architecture_reporting"
  filename         = "architecture_reporting.zip"
  source_code_hash = data.archive_file.architecture_reporting_code.output_base64sha256
  role             = aws_iam_role.lambda_iam_role.arn
  runtime          = var.python_runtime_target
  handler          = "architecture_reporting.lambda_handler"
  timeout          = var.lambda_timeout
  kms_key_arn      = aws_kms_key.lambda_env_var_kms_key.arn

  environment {
    variables = {
      AUTHORIZATION_HEADER = var.lambda_authorization_header
      CONFLUENCE_URL       = var.confluence_url
      CONFLUENCE_EMAIL     = var.confluence_email
      CONFLUENCE_TOKEN     = var.confluence_token
      CONFLUENCE_SPACE_ID  = var.confluence_space_id
      CONFLUENCE_ARC_TAG   = var.confluence_arc_tag
      CONFLUENCE_DA_TAG    = var.confluence_da_tag
      ELASTIC_URL          = var.elastic_url
      ELASTIC_DATASTREAM   = var.architecture_report_elastic_datastream
      ELASTIC_API_KEY      = var.elastic_api_key
      ELASTIC_WATCHER_ID   = var.architecture_report_elastic_watcher_id
    }
  }

  layers = [aws_lambda_layer_version.reporting_dependencies_lambda_layer_version.arn, "arn:aws:lambda:ap-southeast-2:336392948345:layer:AWSSDKPandas-Python311:2"]

  tags = local.common_tags
}

resource "aws_lambda_function_url" "architecture_reporting_function_url" {
  function_name      = aws_lambda_function.architecture_reporting_function.function_name
  authorization_type = "NONE"
}

resource "aws_cloudwatch_event_rule" "architecture_reporting_cloudwatch_event_rule" {
  name                = "run_architecture_reporting_function"
  description         = "Schedule architecture_reporting lambda function"
  schedule_expression = var.architecture_report_schedule_expression

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "architecture_reporting_cloudwatch_event_target" {
  target_id = "lambda-function-target"
  rule      = aws_cloudwatch_event_rule.architecture_reporting_cloudwatch_event_rule.name
  arn       = aws_lambda_function.architecture_reporting_function.arn
}

resource "aws_lambda_permission" "allow_architecture_reporting_execution_from_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.architecture_reporting_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.architecture_reporting_cloudwatch_event_rule.arn
}
