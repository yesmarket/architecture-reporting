data "archive_file" "code" {
  type        = "zip"
  source_file = "${path.root}/../code/${var.function_name}.py"
  output_path = "${path.module}/${var.function_name}.zip"
}

resource "aws_lambda_function" "lambda_function" {
  function_name    = var.function_name
  filename         = "${path.module}/${var.function_name}.zip"
  source_code_hash = data.archive_file.code.output_base64sha256
  role             = var.iam_role_arn
  runtime          = var.runtime
  handler          = "${var.function_name}.lambda_handler"
  timeout          = var.timeout
  kms_key_arn      = var.kms_key_arn

  environment {
    variables = {
      AUTHORIZATION_HEADER = var.authorization_header
      CONFLUENCE_URL       = var.confluence_url
      CONFLUENCE_EMAIL     = var.confluence_email
      CONFLUENCE_TOKEN     = var.confluence_token
      CONFLUENCE_SPACE_ID  = var.confluence_space_id
      ELASTIC_URL          = var.elastic_url
      ELASTIC_DATASTREAM   = var.elastic_datastream
      ELASTIC_API_KEY      = var.elastic_api_key
      ELASTIC_WATCHER_ID   = var.elastic_watcher_id
    }
  }

  layers = [var.lambda_layer_version_arn, "arn:aws:lambda:ap-southeast-2:336392948345:layer:AWSSDKPandas-Python311:2"]

  tags = var.common_tags
}

resource "aws_lambda_function_url" "lambda_function_url" {
  function_name      = aws_lambda_function.lambda_function.function_name
  authorization_type = "NONE"
}

resource "aws_cloudwatch_event_rule" "cloudwatch_event_rule" {
  name                = "${var.function_name}_cloudwatch_event_rule"
  description         = "Schedule ${var.function_name} lambda function"
  schedule_expression = var.schedule_expression

  tags = var.common_tags
}

resource "aws_cloudwatch_event_target" "cloudwatch_event_target" {
  target_id = "lambda-function-target"
  rule      = aws_cloudwatch_event_rule.cloudwatch_event_rule.name
  arn       = aws_lambda_function.lambda_function.arn
}

resource "aws_lambda_permission" "allow_execution_from_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cloudwatch_event_rule.arn
}
