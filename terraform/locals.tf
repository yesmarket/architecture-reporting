locals {

  common_tags = {
    company     = "hummgroup"
    project     = "architecture-reporting"
    environment = var.environment
  }

  naming_prefix = "${var.naming_prefix}-${var.environment}"
}
