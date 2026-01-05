variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "node_count" {
  description = "Number of nodes"
  type        = number
  default     = 0
}
