##################################################################################
# AWS lambda functions
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
  schedule_expression      = var.architecture_report_schedule_expression

  common_tags = local.common_tags
}

##################################################################################
# AWS nginx reverse proxy
##################################################################################

# DATA SOURCES #
data "aws_ssm_parameter" "amzn2_linux" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

data "aws_availability_zones" "available" {
  state = "available"
}

# NETWORKING #
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = local.common_tags
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = local.common_tags
}

resource "aws_subnet" "public" {
  cidr_block              = var.vpc_public_subnet_cidr_block
  vpc_id                  = aws_vpc.this.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = local.common_tags

  depends_on = [aws_internet_gateway.this]
}

# ROUTING #
resource "aws_route_table" "this" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = local.common_tags
}

resource "aws_route_table_association" "this" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.this.id
}

# SECURITY GROUPS #
# Nginx security group 
resource "aws_security_group" "reverse_proxy" {
  name   = "reverse_proxy_sg"
  vpc_id = aws_vpc.this.id

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# INSTANCES #

resource "aws_key_pair" "ssh" {
  key_name   = "ssh"
  public_key = var.ssh_public_key
}

resource "aws_instance" "reverse_proxy" {
  ami                         = nonsensitive(data.aws_ssm_parameter.amzn2_linux.value)
  instance_type               = var.instance_type
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.reverse_proxy.id]
  key_name                    = aws_key_pair.ssh.key_name

  user_data_replace_on_change = true
  user_data = templatefile("${path.root}/templates/reverse_proxy_userdata.sh", {
    playbook_repository = var.reverse_proxy_ansible_playbook_repository
    kibana_credentials  = var.kibana_credentials
    domain = var.reporting_dns_domain
    registered_email_for_domain = var.registered_email_for_domain
  })

  tags = local.common_tags
}

resource "aws_eip" "this" {
  instance = aws_instance.reverse_proxy.id
  domain   = "vpc"

  tags = local.common_tags

  depends_on = [aws_internet_gateway.this]
}
