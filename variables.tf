variable "region" {
  description = "AWS region"
  default     = "eu-central-1"
}

variable "lambda1_function_name" {
  description = "Proxy"
  default     = "lambda1"
}

variable "lambda2_function_name" {
  description = "Image processing"
  default     = "lambda2"
}

variable "api_gateway_name" {
  description = "Name of the API Gateway"
  default     = "LambdaAPI"
}
