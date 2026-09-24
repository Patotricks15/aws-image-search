"""index_image: embeds an image's labels with a Hugging Face model and stores the vector
in DynamoDB, standing in for Amazon OpenSearch Service (not available on floci)."""
import json
import os

import boto3
from embeddings import embed_text

TABLE_NAME = os.environ["TABLE_NAME"]
REGION = os.environ.get("REGION", "us-east-1")
ENDPOINT_URL = "http://localhost:4566"

dynamodb = boto3.resource(
    "dynamodb",
    region_name=REGION,
    endpoint_url=ENDPOINT_URL,
    aws_access_key_id="test",
    aws_secret_access_key="test",
)
table = dynamodb.Table(TABLE_NAME)


def lambda_handler(event, context):
    indexed = []

    for record in event.get("Records", []):
        message = json.loads(record["body"])
        image_key = message["imageKey"]

        item = table.get_item(Key={"imageKey": image_key}).get("Item")
        if not item:
            continue

        labels_text = ", ".join(item.get("labels", []))
        embedding = embed_text(labels_text)

        table.update_item(
            Key={"imageKey": image_key},
            UpdateExpression="SET embedding = :embedding",
            ExpressionAttributeValues={":embedding": [str(value) for value in embedding]},
        )
        indexed.append(image_key)

    return {"indexed": indexed}
