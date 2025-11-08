locals {
  common_tags = {
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

module "upload_bucket" {
  source = "./modules/s3"

  bucket_name         = var.upload_bucket_name
  versioning_enabled  = true
  block_public_access = true

  lifecycle_rules = [
    {
      id              = "delete-old-uploads"
      status          = "Enabled"
      expiration_days = var.upload_retention_days
      noncurrent_version_expiration_days = 30
    }
  ]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-upload"
  })
}

module "processed_bucket" {
  source = "./modules/s3"

  bucket_name         = var.processed_bucket_name
  versioning_enabled  = true
  block_public_access = true

  lifecycle_rules = [
    {
      id     = "transition-to-ia"
      status = "Enabled"
      transitions = [
        {
          days          = 90
          storage_class = "STANDARD_IA"
        },
        {
          days          = 180
          storage_class = "GLACIER_IR"
        }
      ]
    }
  ]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-processed"
  })
}

module "image_queue" {
  source = "./modules/sqs"

  queue_name                 = "${var.project_name}-queue"
  visibility_timeout_seconds = var.sqs_visibility_timeout
  message_retention_seconds  = var.sqs_message_retention
  enable_dlq                 = true
  max_receive_count          = var.dlq_max_receive_count

  tags = local.common_tags
}

resource "aws_sqs_queue_policy" "image_queue_policy" {
  queue_url = module.image_queue.queue_url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = module.image_queue.queue_arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = module.upload_bucket.bucket_arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_notification" "upload_notification" {
  bucket = module.upload_bucket.bucket_id

  queue {
    queue_arn     = module.image_queue.queue_arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".jpg"
  }

  queue {
    queue_arn     = module.image_queue.queue_arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".jpeg"
  }

  queue {
    queue_arn     = module.image_queue.queue_arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".png"
  }

  depends_on = [aws_sqs_queue_policy.image_queue_policy]
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

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-lambda-role"
  })
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
        Resource = "${module.upload_bucket.bucket_arn}/*"
      },
      {
        Sid    = "S3WriteProcessedBucket"
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${module.processed_bucket.bucket_arn}/*"
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
        Resource = module.image_queue.queue_arn
      },
      {
        Sid    = "SQSSendToDLQ"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = module.image_queue.dlq_arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${module.lambda_processor.log_group_arn}:*"
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

module "lambda_processor" {
  source = "./modules/lambda"

  function_name                  = "${var.project_name}-function"
  filename                       = data.archive_file.lambda_zip.output_path
  handler                        = "handler.lambda_handler"
  runtime                        = "python3.11"
  role_arn                       = aws_iam_role.lambda_role.arn
  source_code_hash               = data.archive_file.lambda_zip.output_base64sha256
  timeout                        = 60
  memory_size                    = 512
  reserved_concurrent_executions = var.lambda_reserved_concurrency
  log_retention_days             = var.log_retention_days
  dead_letter_target_arn         = module.image_queue.dlq_arn
  tracing_mode                   = "Active"

  environment_variables = {
    PROCESSED_BUCKET = module.processed_bucket.bucket_id
    IMAGE_WIDTH      = tostring(var.image_width)
    IMAGE_HEIGHT     = tostring(var.image_height)
    LOG_LEVEL        = var.log_level
  }

  event_source_arn        = module.image_queue.queue_arn
  batch_size              = 10
  event_source_enabled    = true
  maximum_concurrency     = var.lambda_max_concurrency
  function_response_types = ["ReportBatchItemFailures"]

  tags = local.common_tags
}
