variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "versioning_enabled" {
  description = "Enable versioning for the bucket"
  type        = bool
  default     = true
}

variable "sse_algorithm" {
  description = "Server-side encryption algorithm"
  type        = string
  default     = "AES256"
}

variable "block_public_access" {
  description = "Block all public access to the bucket"
  type        = bool
  default     = true
}

variable "lifecycle_rules" {
  description = "List of lifecycle rules"
  type = list(object({
    id                                  = string
    status                              = string
    expiration_days                     = optional(number)
    noncurrent_version_expiration_days  = optional(number)
    transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to the bucket"
  type        = map(string)
  default     = {}
}
