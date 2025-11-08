resource "aws_sqs_queue" "dlq" {
  count                     = var.enable_dlq ? 1 : 0
  name                      = "${var.queue_name}-dlq"
  message_retention_seconds = var.message_retention_seconds
  sqs_managed_sse_enabled   = var.enable_encryption

  tags = merge(
    var.tags,
    {
      Name = "${var.queue_name}-dlq"
    }
  )
}

resource "aws_sqs_queue" "main" {
  name                       = var.queue_name
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  sqs_managed_sse_enabled    = var.enable_encryption
  receive_wait_time_seconds  = var.receive_wait_time_seconds

  dynamic "redrive_policy" {
    for_each = var.enable_dlq ? [1] : []
    content {
      deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
      maxReceiveCount     = var.max_receive_count
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.queue_name
    }
  )
}

resource "aws_sqs_queue_policy" "main" {
  count     = var.queue_policy != null ? 1 : 0
  queue_url = aws_sqs_queue.main.id
  policy    = var.queue_policy
}
