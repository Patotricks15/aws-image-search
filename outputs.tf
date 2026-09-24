output "images_bucket_name" {
  description = "Name of the S3 bucket receiving raw image uploads."
  value       = aws_s3_bucket.images.bucket
}

output "image_catalog_table_name" {
  description = "Name of the DynamoDB table storing labeled images and their embeddings."
  value       = aws_dynamodb_table.image_catalog.name
}

output "labeling_queue_url" {
  description = "URL of the SQS queue feeding the label_images Lambda."
  value       = aws_sqs_queue.labeling_queue.id
}

output "indexing_queue_url" {
  description = "URL of the SQS queue feeding the index_image Lambda."
  value       = aws_sqs_queue.indexing_queue.id
}

output "search_api_endpoint" {
  description = "Base URL of the search API."
  value       = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.search.id}/${var.api_stage_name}/_user_request_"
}

output "lambda_function_names" {
  description = "Names of the deployed Lambda functions."
  value       = { for k, fn in aws_lambda_function.functions : k => fn.function_name }
}
