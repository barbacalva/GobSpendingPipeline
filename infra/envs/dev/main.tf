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

module "s3_lake" {
  source            = "../../modules/s3_bucket"
  name              = "spendings-lake-${var.stage}"
  tags              = local.common_tags
  enable_versioning = false
}

resource "aws_dynamodb_table" "igae_files" {
  name         = "igae_downloads-${var.stage}"
  hash_key     = "file_id"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "file_id"
    type = "S"
  }

  tags = local.common_tags
}

module "lambda_igae_pull" {
  source         = "../../modules/lambda"
  function_name  = "igae-pull-${var.stage}"
  source_dir     = "../../../src/lambdas/igae_pull"
  stage          = var.stage
  target_bucket  = module.s3_raw.bucket_id
  target_bucket_arn  = module.s3_raw.bucket_arn
  dynamodb_table = aws_dynamodb_table.igae_files.name
  tags           = local.common_tags
}