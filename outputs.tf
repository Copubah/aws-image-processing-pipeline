output "upload_bucket_name" {
  description = "Name of the upload S3 bucket"
  value       = aws_s3_bucket.upload.id
}

output "upload_bucket_arn" {
  description = "ARN of the upload S3 bucket"
  value       = aws_s3_bucket.upload.arn
}

output "processed_bucket_name" {
  description = "Name of the processed S3 bucket"
  value       = aws_s3_bucket.processed.id
}

output "processed_bucket_arn" {
  description = "ARN of the processed S3 bucket"
  value       = aws_s3_bucket.processed.arn
}

output "sqs_queue_url" {
  description = "URL of the SQS queue"
  value       = aws_sqs_queue.image_queue.url
}

output "sqs_queue_arn" {
  description = "ARN of the SQS queue"
  value       = aws_sqs_queue.image_queue.arn
}

output "dlq_url" {
  description = "URL of the Dead Letter Queue"
  value       = aws_sqs_queue.image_dlq.url
}

output "dlq_arn" {
  description = "ARN of the Dead Letter Queue"
  value       = aws_sqs_queue.image_dlq.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.image_processor.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.image_processor.arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda IAM role"
  value       = aws_iam_role.lambda_role.arn
}
