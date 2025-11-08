resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum", label = "Invocations" }],
            [".", "Errors", { stat = "Sum", label = "Errors" }],
            [".", "Throttles", { stat = "Sum", label = "Throttles" }],
            [".", "Duration", { stat = "Average", label = "Avg Duration" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Lambda Metrics"
          dimensions = {
            FunctionName = aws_lambda_function.image_processor.function_name
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", { stat = "Average", label = "Messages in Queue" }],
            [".", "NumberOfMessagesSent", { stat = "Sum", label = "Messages Sent" }],
            [".", "NumberOfMessagesDeleted", { stat = "Sum", label = "Messages Deleted" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "SQS Queue Metrics"
          dimensions = {
            QueueName = aws_sqs_queue.image_queue.name
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", { stat = "Average", label = "Messages in DLQ" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Dead Letter Queue"
          dimensions = {
            QueueName = aws_sqs_queue.image_dlq.name
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/S3", "NumberOfObjects", { stat = "Average", label = "Upload Bucket Objects" }],
            ["...", { stat = "Average", label = "Processed Bucket Objects" }]
          ]
          period = 86400
          stat   = "Average"
          region = var.aws_region
          title  = "S3 Object Count"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_metric_filter" "image_processing_errors" {
  name           = "${var.project_name}-processing-errors"
  log_group_name = aws_cloudwatch_log_group.lambda_logs.name
  pattern        = "[time, request_id, level = ERROR*, ...]"

  metric_transformation {
    name      = "ImageProcessingErrors"
    namespace = var.project_name
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "processing_errors" {
  alarm_name          = "${var.project_name}-processing-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ImageProcessingErrors"
  namespace           = var.project_name
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Alert when image processing errors exceed threshold"
  treat_missing_data  = "notBreaching"

  tags = {
    Name        = "${var.project_name}-processing-error-alarm"
    Environment = "production"
  }
}
