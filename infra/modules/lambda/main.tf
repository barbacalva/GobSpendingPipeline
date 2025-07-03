############################
# 1. Packaging: ZIP in-place
############################
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/build/${var.function_name}-${var.stage}.zip"
}

############################
# 2. IAM Role + Policy
############################
resource "aws_iam_role" "exec" {
  name               = "${var.function_name}-exec-${var.stage}"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "s3_put" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${var.target_bucket_arn}/*"]
  }
  statement {
    actions   = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "s3_put" {
  name   = "${var.function_name}-s3-${var.stage}"
  policy = data.aws_iam_policy_document.s3_put.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.exec.name
  policy_arn = aws_iam_policy.s3_put.arn
}

############################
# 3. Lambda Function
############################
resource "aws_lambda_function" "this" {
  function_name = "${var.function_name}-${var.stage}"
  role          = aws_iam_role.exec.arn
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"
  filename      = data.archive_file.lambda_zip.output_path
  memory_size   = 256
  timeout       = 30

  environment {
    variables = {
      TARGET_BUCKET = var.target_bucket
    }
  }

  tags = var.tags
}

############################
# 4. CloudWatch Event Rule (ejecución manual/CRON opcional)
############################
resource "aws_cloudwatch_event_rule" "monthly" {
  name                = "${var.function_name}-on-demand-${var.stage}"
  schedule_expression = "cron(0 12 26 * ? *)"
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