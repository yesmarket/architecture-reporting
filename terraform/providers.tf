provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::992382606341:role/OrganizationAccountAccessRole"
  }
}
