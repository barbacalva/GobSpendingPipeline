############################
# 1. Packaging: ZIP in-place
############################
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/build/${var.function_name}.zip"
}

############################
# 2. IAM Role + Policy
############################
data "aws_caller_identity" "me" {}
data "aws_region" "this" {}

# ARN del bucket → arn:aws:s3:::bucket
locals {
  bucket_objects  = "${var.target_bucket_arn}/*"
  dynamodb_arn    = format("arn:aws:dynamodb:%s:%s:table/%s",
                            data.aws_region.this.name,
                            data.aws_caller_identity.me.account_id,
                            var.dynamodb_table)
}

data "aws_iam_policy_document" "policy" {
  statement {
    sid     = "PutToRaw"
    actions = ["s3:PutObject"]
    resources = [local.bucket_objects]
  }

  statement {
    sid     = "DDBReadWrite"
    actions = ["dynamodb:GetItem", "dynamodb:PutItem"]
    resources = [local.dynamodb_arn]
  }

  statement {
    sid = "Logs"
    actions = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
}


resource "aws_iam_role" "exec" {
  name = "${var.function_name}-exec-${var.stage}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action = "sts:AssumeRole"
      }]
  })
  tags = var.tags
}

resource "aws_iam_policy" "inline" {
  name   = "${var.function_name}-policy-${var.stage}"
  policy = data.aws_iam_policy_document.policy.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.exec.name
  policy_arn = aws_iam_policy.inline.arn
}

############################
# 3. Lambda Function
############################
resource "aws_lambda_function" "this" {
  function_name = "${var.function_name}"
  role          = aws_iam_role.exec.arn
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  memory_size   = 256
  timeout       = 30

  environment {
    variables = {
      TARGET_BUCKET = var.target_bucket
      DDB_TABLE = var.dynamodb_table
    }
  }

  tags = var.tags
}

############################
# 4. CloudWatch Event Rule (ejecución manual/CRON opcional)
############################
resource "aws_cloudwatch_event_rule" "monthly" {
  name                = "${var.function_name}-on-demand-${var.stage}"
  schedule_expression = "cron(0 8 * * ? *)"
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "invoke" {
  rule      = aws_cloudwatch_event_rule.monthly.name
  target_id = "lambda"
  arn       = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "allow_events" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monthly.arn
}