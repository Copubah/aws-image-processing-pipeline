variable "queue_name" {
  description = "Name of the SQS queue"
  type        = string
}

variable "visibility_timeout_seconds" {
  description = "Visibility timeout in seconds"
  type        = number
  default     = 300
}

variable "message_retention_seconds" {
  description = "Message retention period in seconds"
  type        = number
  default     = 345600
}

variable "receive_wait_time_seconds" {
  description = "Long polling wait time in seconds"
  type        = number
  default     = 20
}

variable "enable_encryption" {
  description = "Enable SQS managed encryption"
  type        = bool
  default     = true
}

variable "enable_dlq" {
  description = "Enable Dead Letter Queue"
  type        = bool
  default     = true
}

variable "max_receive_count" {
  description = "Maximum receives before sending to DLQ"
  type        = number
  default     = 3
}

variable "queue_policy" {
  description = "SQS queue policy JSON"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to the queue"
  type        = map(string)
  default     = {}
}
