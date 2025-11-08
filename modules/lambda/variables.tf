variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "filename" {
  description = "Path to the Lambda deployment package"
  type        = string
}

variable "handler" {
  description = "Lambda function handler"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.11"
}

variable "role_arn" {
  description = "ARN of the IAM role for Lambda"
  type        = string
}

variable "source_code_hash" {
  description = "Base64-encoded SHA256 hash of the package"
  type        = string
}

variable "timeout" {
  description = "Function timeout in seconds"
  type        = number
  default     = 60
}

variable "memory_size" {
  description = "Amount of memory in MB"
  type        = number
  default     = 512
}

variable "environment_variables" {
  description = "Environment variables for the function"
  type        = map(string)
  default     = {}
}

variable "dead_letter_target_arn" {
  description = "ARN of the DLQ for failed invocations"
  type        = string
  default     = null
}

variable "tracing_mode" {
  description = "X-Ray tracing mode"
  type        = string
  default     = "Active"
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrent executions"
  type        = number
  default     = -1
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "event_source_arn" {
  description = "ARN of the event source"
  type        = string
  default     = null
}

variable "batch_size" {
  description = "Batch size for event source"
  type        = number
  default     = 10
}

variable "event_source_enabled" {
  description = "Enable event source mapping"
  type        = bool
  default     = true
}

variable "maximum_concurrency" {
  description = "Maximum concurrent executions for event source"
  type        = number
  default     = null
}

variable "function_response_types" {
  description = "Function response types"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
