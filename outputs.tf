output "upload_bucket_name" {
  description = "Name of the upload S3 bucket"
  value       = module.upload_bucket.bucket_id
}

output "upload_bucket_arn" {
  description = "ARN of the upload S3 bucket"
  value       = module.upload_bucket.bucket_arn
}

output "processed_bucket_name" {
  description = "Name of the processed S3 bucket"
  value       = module.processed_bucket.bucket_id
}

output "processed_bucket_arn" {
  description = "ARN of the processed S3 bucket"
  value       = module.processed_bucket.bucket_arn
}

output "sqs_queue_url" {
  description = "URL of the SQS queue"
  value       = module.image_queue.queue_url
}

output "sqs_queue_arn" {
  description = "ARN of the SQS queue"
  value       = module.image_queue.queue_arn
}

output "dlq_url" {
  description = "URL of the Dead Letter Queue"
  value       = module.image_queue.dlq_url
}

output "dlq_arn" {
  description = "ARN of the Dead Letter Queue"
  value       = module.image_queue.dlq_arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.lambda_processor.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = module.lambda_processor.function_arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda IAM role"
  value       = aws_iam_role.lambda_role.arn
}
