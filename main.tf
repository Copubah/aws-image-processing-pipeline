resource "aws_s3_bucket" "upload" {
  bucket = var.upload_bucket_name

  tags = {
    Name        = "${var.project_name}-upload"
    Environment = "production"
  }
}

resource "aws_s3_bucket_versioning" "upload" {
  bucket = aws_s3_bucket.upload.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "upload" {
  bucket = aws_s3_bucket.upload.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "upload" {
  bucket = aws_s3_bucket.upload.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "upload" {
  bucket = aws_s3_bucket.upload.id

  rule {
    id     = "delete-old-uploads"
    status = "Enabled"

    expiration {
      days = var.upload_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket" "processed" {
  bucket = var.processed_bucket_name

  tags = {
    Name        = "${var.project_name}-processed"
    Environment = "production"
  }
}

resource "aws_s3_bucket_versioning" "processed" {
  bucket = aws_s3_bucket.processed.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "processed" {
  bucket = aws_s3_bucket.processed.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 180
      storage_class = "GLACIER_IR"
    }
  }
}

resource "aws_s3_bucket_notification" "upload_notification" {
  bucket = aws_s3_bucket.upload.id

  queue {
    queue_arn     = aws_sqs_queue.image_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".jpg"
  }

  queue {
    queue_arn     = aws_sqs_queue.image_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".jpeg"
  }

  queue {
    queue_arn     = aws_sqs_queue.image_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".png"
  }

  depends_on = [aws_sqs_queue_policy.image_queue_policy]
}

resource "aws_sqs_queue" "image_dlq" {
  name                      = "${var.project_name}-dlq"
  message_retention_seconds = var.sqs_message_retention
  sqs_managed_sse_enabled   = true

  tags = {
    Name        = "${var.project_name}-dlq"
    Environment = "production"
  }
}

resource "aws_sqs_queue" "image_queue" {
  name                       = "${var.project_name}-queue"
  visibility_timeout_seconds = var.sqs_visibility_timeout
  message_retention_seconds  = var.sqs_message_retention
  sqs_managed_sse_enabled    = true
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.image_dlq.arn
    maxReceiveCount     = var.dlq_max_receive_count
  })

  tags = {
    Name        = "${var.project_name}-queue"
    Environment = "production"
  }
}

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${var.project_name}-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Alert when messages appear in DLQ"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.image_dlq.name
  }

  tags = {
    Name        = "${var.project_name}-dlq-alarm"
    Environment = "production"
  }
}

resource "aws_sqs_queue_policy" "image_queue_policy" {
  queue_url = aws_sqs_queue.image_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.image_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.upload.arn
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-lambda-role"
    Environment = "production"
  }
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ReadUploadBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.upload.arn}/*"
      },
      {
        Sid    = "S3WriteProcessedBucket"
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.processed.arn}/*"
      },
      {
        Sid    = "SQSProcessMessages"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = aws_sqs_queue.image_queue.arn
      },
      {
        Sid    = "SQSSendToDLQ"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.image_dlq.arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.lambda_logs.arn}:*"
      },
      {
        Sid    = "XRayTracing"
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-function"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-logs"
    Environment = "production"
  }
}

resource "aws_lambda_function" "image_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-function"
  role            = aws_iam_role.lambda_role.arn
  handler         = "handler.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 60
  memory_size     = 512

  environment {
    variables = {
      PROCESSED_BUCKET = aws_s3_bucket.processed.id
      IMAGE_WIDTH      = var.image_width
      IMAGE_HEIGHT     = var.image_height
      LOG_LEVEL        = var.log_level
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.image_dlq.arn
  }

  tracing_config {
    mode = "Active"
  }

  reserved_concurrent_executions = var.lambda_reserved_concurrency

  tags = {
    Name        = "${var.project_name}-function"
    Environment = "production"
  }

  depends_on = [aws_cloudwatch_log_group.lambda_logs]
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.image_queue.arn
  function_name    = aws_lambda_function.image_processor.arn
  batch_size       = 10
  enabled          = true

  scaling_config {
    maximum_concurrency = var.lambda_max_concurrency
  }

  function_response_types = ["ReportBatchItemFailures"]
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert when Lambda function has errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.image_processor.function_name
  }

  tags = {
    Name        = "${var.project_name}-lambda-error-alarm"
    Environment = "production"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.project_name}-lambda-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert when Lambda function is throttled"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.image_processor.function_name
  }

  tags = {
    Name        = "${var.project_name}-lambda-throttle-alarm"
    Environment = "production"
  }
}
