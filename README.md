# AWS Project: Image Search

Event-driven image labeling and semantic search with Floci and Terraform:

1. an image lands in the upload bucket;
2. S3 publishes the event to SNS, which feeds the labeling queue;
3. `label_images` calls Amazon Rekognition and stores the labels in DynamoDB, then queues the image for indexing;
4. `index_image` embeds the labels with a lightweight Hugging Face model and stores the vector alongside the record;
5. `search_images`, exposed through API Gateway, embeds the query and ranks catalog images by cosine similarity.

> **Why Hugging Face instead of Amazon OpenSearch Service?** OpenSearch domains require a paid tier that the free floci emulator does not support. As a fallback, this project embeds labels and queries with the lightweight `sentence-transformers/all-MiniLM-L6-v2` model through the Hugging Face Inference API and ranks results with cosine similarity in DynamoDB — the same role OpenSearch's k-NN search would normally play.

## Prerequisites

- Docker
- Terraform 1.5+
- AWS CLI
- A Hugging Face account and API token (free tier), set via `TF_VAR_huggingface_api_token`

## Start Floci

```bash
docker compose up -d
```

## Apply Terraform

```bash
export TF_VAR_huggingface_api_token=hf_xxx...
terraform init
terraform apply
```

## Architecture

The architecture diagram is maintained as an editable [draw.io](https://www.drawio.com/) file at [docs/architecture.drawio](docs/architecture.drawio), generated programmatically with the [drawpyo](https://github.com/MerrimanInd/drawpyo) Python library (the only Python package for building `.drawio` files). GitHub renders `.drawio` files natively — open the file directly in this repository to view or edit the diagram, or open it locally with the draw.io desktop app / [app.diagrams.net](https://app.diagrams.net/).

It shows the same flow described above: Images Bucket (S3) → Image Uploaded (SNS) → Labeling Queue (SQS) → `label_images` Lambda (calls Rekognition, writes to DynamoDB) → Indexing Queue (SQS) → `index_image` Lambda (calls the Hugging Face embeddings API, updates DynamoDB); separately, a Search Client hits API Gateway's `GET /search` → `search_images` Lambda (also calls Hugging Face) → reads DynamoDB via scan + cosine similarity. This Hugging Face embedding lane is what replaces Amazon OpenSearch Service, which the free "floci" emulator doesn't support.

To regenerate the diagram after changing the architecture:

```bash
python3 -m venv .diagram-venv
.diagram-venv/bin/pip install drawpyo
.diagram-venv/bin/python scripts/generate_diagram.py
```

## Test the pipeline

Upload an image to trigger labeling and indexing:

```bash
export ENDPOINT=http://localhost:4566
export IMAGES_BUCKET=$(terraform output -raw images_bucket_name)
export TABLE_NAME=$(terraform output -raw image_catalog_table_name)

curl -L "https://upload.wikimedia.org/wikipedia/commons/3/3f/Fronalpstock_big.jpg" -o mountain.jpg
aws --endpoint-url "$ENDPOINT" s3 cp ./mountain.jpg "s3://$IMAGES_BUCKET/mountain.jpg"
rm -f ./mountain.jpg
```

Check the catalog entry once labeling and indexing have run:

```bash
aws --endpoint-url "$ENDPOINT" dynamodb get-item \
  --table-name "$TABLE_NAME" \
  --key '{"imageKey": {"S": "mountain.jpg"}}'
```

Search the catalog by meaning, not just exact label matches:

```bash
API_URL=$(terraform output -raw search_api_endpoint)
curl -s "$API_URL/search?q=snowy+mountains" | jq
```

If you want to follow the execution, watch the Floci container logs:

```bash
docker compose logs -f floci
```

## Clean up

```bash
terraform destroy
docker compose down
```
