variable "project_name" {
  description = "Project name used as prefix for all resources."
  type        = string
  default     = "floci-image-search"
}

variable "aws_region" {
  description = "AWS region (simulated by floci)."
  type        = string
  default     = "us-east-1"
}

variable "catalog_table_name" {
  description = "Name of the DynamoDB table storing labeled images and their embeddings."
  type        = string
  default     = "image-catalog"
}

variable "api_stage_name" {
  description = "Deployment stage name for the search API Gateway."
  type        = string
  default     = "v1"
}

variable "huggingface_model_id" {
  description = "Hugging Face model used to embed labels and search queries. OpenSearch is not available on the free floci emulator, so this lightweight model stands in for it."
  type        = string
  default     = "sentence-transformers/all-MiniLM-L6-v2"
}

variable "huggingface_api_token" {
  description = "Hugging Face Inference API token used to call the embedding model."
  type        = string
  default     = ""
  sensitive   = true
}
