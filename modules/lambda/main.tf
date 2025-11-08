resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_lambda_function" "this" {
  filename         = var.filename
  function_name    = var.function_name
  role            = var.role_arn
  handler         = var.handler
  source_code_hash = var.source_code_hash
  runtime         = var.runtime
  timeout         = var.timeout
  memory_size     = var.memory_size

  environment {
    variables = var.environment_variables
  }

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_target_arn != null ? [1] : []
    content {
      target_arn = var.dead_letter_target_arn
    }
  }

  tracing_config {
    mode = var.tracing_mode
  }

  reserved_concurrent_executions = var.reserved_concurrent_executions

  tags = var.tags

  depends_on = [aws_cloudwatch_log_group.this]
}

resource "aws_lambda_event_source_mapping" "this" {
  count            = var.event_source_arn != null ? 1 : 0
  event_source_arn = var.event_source_arn
  function_name    = aws_lambda_function.this.arn
  batch_size       = var.batch_size
  enabled          = var.event_source_enabled

  dynamic "scaling_config" {
    for_each = var.maximum_concurrency != null ? [1] : []
    content {
      maximum_concurrency = var.maximum_concurrency
    }
  }

  function_response_types = var.function_response_types
}
