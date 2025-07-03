terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }
  required_version = ">= 1.2"
}

provider "aws" {
  region  = "eu-west-1"
  profile = "${var.profile}"
}

module "s3_raw" {
  source            = "../../modules/s3_bucket"
  name              = "spendings-raw-${var.stage}"
  tags              = local.common_tags
  enable_versioning = true
}

module "s3_curated" {
  source            = "../../modules/s3_bucket"
  name              = "spendings-curated-${var.stage}"
  tags              = local.common_tags
  enable_versioning = false
}

module "lambda_smoke" {
  source         = "../../modules/lambda"
  function_name  = "gob-spending-smoke-writer"
  source_dir     = "../../../src"
  stage          = var.stage
  target_bucket  = module.s3_raw.bucket_id
  target_bucket_arn  = module.s3_raw.bucket_arn
  tags           = local.common_tags
}