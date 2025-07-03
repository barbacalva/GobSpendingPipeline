locals {
  common_tags = {
    Project     = "FiscalHub"
    Environment = var.stage            # "dev", "prod",…
    ManagedBy   = "Terraform"
  }
}