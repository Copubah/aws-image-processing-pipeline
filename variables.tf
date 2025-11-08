variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "image-processor"
}

variable "upload_bucket_name" {
  description = "Name for the upload S3 bucket"
  type        = string
}

variable "processed_bucket_name" {
  description = "Name for the processed S3 bucket"
  type        = string
}

variable "image_width" {
  description = "Target width for resized images"
  type        = number
  default     = 800
}

variable "image_height" {
  description = "Target height for resized images"
  type        = number
  default     = 600
}

variable "sqs_visibility_timeout" {
  description = "SQS visibility timeout in seconds"
  type        = number
  default     = 300
}

variable "sqs_message_retention" {
  description = "SQS message retention period in seconds"
  type        = number
  default     = 345600
}

variable "dlq_max_receive_count" {
  description = "Maximum receives before sending to DLQ"
  type        = number
  default     = 3
}

variable "upload_retention_days" {
  description = "Number of days to retain uploaded images"
  type        = number
  default     = 90
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "log_level" {
  description = "Lambda function log level"
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR"], var.log_level)
    error_message = "Log level must be DEBUG, INFO, WARNING, or ERROR"
  }
}

variable "lambda_reserved_concurrency" {
  description = "Reserved concurrent executions for Lambda"
  type        = number
  default     = 10
}

variable "lambda_max_concurrency" {
  description = "Maximum concurrent Lambda executions for SQS"
  type        = number
  default     = 5
}
