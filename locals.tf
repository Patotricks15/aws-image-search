locals {
  name_prefix = var.project_name

  common_tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
    Demo      = "Image Search"
  }

  # search_images is invoked synchronously via API Gateway, not from a queue.
  queue_triggered_functions = {
    label_images = { queue = "labeling" }
    index_image  = { queue = "indexing" }
  }

  lambda_functions = merge(local.queue_triggered_functions, {
    search_images = {}
  })
}
