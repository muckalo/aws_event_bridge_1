provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region = var.region
}

# Create an S3 bucket
resource "aws_s3_bucket" "event_bucket" {
  bucket = "agrcic-s3-bucket-event-bridge-1"  # Change this to a unique name
  force_destroy = true
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket      = aws_s3_bucket.event_bucket.id
  eventbridge = true
}

# Create a Lambda execution role
resource "aws_iam_role" "lambda_role" {
  name = "agrcic-role-eventbridge_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Attach necessary policies to the role
resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create the Lambda function
resource "aws_lambda_function" "event_lambda" {
  function_name = "agrcic-eventbridge_lambda"
  handler       = "lambda_1.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_role.arn
  source_code_hash = filebase64sha256("../lambda_functions.zip")  # Update for deployment
  filename = "../lambda_functions.zip"
}

# Create EventBridge rule
resource "aws_cloudwatch_event_rule" "s3_event_rule" {
  name        = "agrcic-s3-upload-event-rule"
  description = "Trigger Lambda on S3 uploads"
  event_pattern = jsonencode({
    "source" = ["aws.s3"],
    "detail-type" = ["AWS API Call via CloudTrail"],
    "detail" = {
      "eventSource" = ["s3.amazonaws.com"],
      "eventName" = ["PutObject"],
      "requestParameters" = {
        "bucketName" = [aws_s3_bucket.event_bucket.bucket]
      }
    }
  })
}

# Create a target for the EventBridge rule
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.s3_event_rule.name
  target_id = "lambda_target"
  arn       = aws_lambda_function.event_lambda.arn
}

# Grant EventBridge permission to invoke the Lambda function
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_event_rule.arn
}
