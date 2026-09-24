# ─── S3 ───────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "images" {
  bucket = "${local.name_prefix}-images"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-images"
  })
}

# ─── DynamoDB (stands in for the OpenSearch index) ───────────────────────────

resource "aws_dynamodb_table" "image_catalog" {
  name         = "${local.name_prefix}-${var.catalog_table_name}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "imageKey"

  attribute {
    name = "imageKey"
    type = "S"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${var.catalog_table_name}"
  })
}

# ─── Event fan-out: S3 -> SNS -> SQS (labeling) ──────────────────────────────

resource "aws_sns_topic" "image_uploaded" {
  name = "${local.name_prefix}-image-uploaded"

  tags = local.common_tags
}

resource "aws_sns_topic_policy" "image_uploaded" {
  arn = aws_sns_topic.image_uploaded.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.image_uploaded.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_s3_bucket.images.arn }
      }
    }]
  })
}

resource "aws_s3_bucket_notification" "images" {
  bucket = aws_s3_bucket.images.id

  topic {
    topic_arn = aws_sns_topic.image_uploaded.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sns_topic_policy.image_uploaded]
}

resource "aws_sqs_queue" "labeling_queue" {
  name = "${local.name_prefix}-labeling-queue"

  tags = local.common_tags
}

resource "aws_sqs_queue_policy" "labeling_queue" {
  queue_url = aws_sqs_queue.labeling_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.labeling_queue.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_sns_topic.image_uploaded.arn }
      }
    }]
  })
}

resource "aws_sns_topic_subscription" "labeling_queue" {
  topic_arn            = aws_sns_topic.image_uploaded.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.labeling_queue.arn
  raw_message_delivery = true
}

# ─── Indexing queue: label_images -> index_image ─────────────────────────────

resource "aws_sqs_queue" "indexing_queue" {
  name = "${local.name_prefix}-indexing-queue"

  tags = local.common_tags
}

# ─── IAM role shared by all Lambda functions ─────────────────────────────────

resource "aws_iam_role" "lambda_exec" {
  name = "${local.name_prefix}-lambda-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name = "${local.name_prefix}-lambda-permissions"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
        ]
        Resource = [
          aws_sqs_queue.labeling_queue.arn,
          aws_sqs_queue.indexing_queue.arn,
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.indexing_queue.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.images.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["rekognition:DetectLabels"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Scan",
        ]
        Resource = aws_dynamodb_table.image_catalog.arn
      },
    ]
  })
}

# ─── Lambda packages (one per function) ──────────────────────────────────────

resource "null_resource" "lambda_packages" {
  for_each = local.lambda_functions

  triggers = {
    source_sha = sha1(join("", [for f in fileset("${path.module}/src/lambda/${each.key}", "*.py") : filesha256("${path.module}/src/lambda/${each.key}/${f}")]))
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/build_lambda_package.sh ${path.module} ${each.key}"
  }
}

data "archive_file" "lambda_zips" {
  for_each = local.lambda_functions

  type        = "zip"
  source_dir  = "${path.module}/.build/${each.key}"
  output_path = "${path.module}/.build/zips/${each.key}.zip"

  depends_on = [null_resource.lambda_packages]
}

# ─── Lambda functions ─────────────────────────────────────────────────────────

resource "aws_lambda_function" "functions" {
  for_each = local.lambda_functions

  function_name = "${local.name_prefix}-${replace(each.key, "_", "-")}"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 256

  filename         = data.archive_file.lambda_zips[each.key].output_path
  source_code_hash = data.archive_file.lambda_zips[each.key].output_base64sha256

  environment {
    variables = {
      TABLE_NAME         = aws_dynamodb_table.image_catalog.name
      INDEXING_QUEUE_URL = aws_sqs_queue.indexing_queue.id
      HF_MODEL_ID        = var.huggingface_model_id
      HF_API_TOKEN       = var.huggingface_api_token
      REGION             = var.aws_region
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${replace(each.key, "_", "-")}"
  })

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy.lambda_permissions,
  ]
}

resource "aws_lambda_event_source_mapping" "queue_triggers" {
  for_each = local.queue_triggered_functions

  event_source_arn = each.value.queue == "labeling" ? aws_sqs_queue.labeling_queue.arn : aws_sqs_queue.indexing_queue.arn
  function_name    = aws_lambda_function.functions[each.key].arn
  batch_size       = 1
}

# ─── API Gateway (search endpoint) ────────────────────────────────────────────

resource "aws_api_gateway_rest_api" "search" {
  name        = "${local.name_prefix}-search-api"
  description = "Search API backed by Hugging Face embeddings instead of Amazon OpenSearch Service."

  tags = local.common_tags
}

resource "aws_api_gateway_resource" "search" {
  rest_api_id = aws_api_gateway_rest_api.search.id
  parent_id   = aws_api_gateway_rest_api.search.root_resource_id
  path_part   = "search"
}

resource "aws_api_gateway_method" "get_search" {
  rest_api_id   = aws_api_gateway_rest_api.search.id
  resource_id   = aws_api_gateway_resource.search.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.querystring.q" = true
  }
}

resource "aws_api_gateway_integration" "get_search" {
  rest_api_id             = aws_api_gateway_rest_api.search.id
  resource_id             = aws_api_gateway_resource.search.id
  http_method             = aws_api_gateway_method.get_search.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.functions["search_images"].invoke_arn
}

resource "aws_lambda_permission" "apigw_search" {
  statement_id  = "AllowAPIGatewayInvokeSearch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.functions["search_images"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.search.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "search" {
  rest_api_id = aws_api_gateway_rest_api.search.id

  triggers = {
    redeployment = sha1(jsonencode([aws_api_gateway_integration.get_search]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_integration.get_search]
}

resource "aws_api_gateway_stage" "search" {
  rest_api_id   = aws_api_gateway_rest_api.search.id
  deployment_id = aws_api_gateway_deployment.search.id
  stage_name    = var.api_stage_name

  tags = local.common_tags
}
