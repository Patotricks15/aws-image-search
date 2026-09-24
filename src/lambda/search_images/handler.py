"""search_images: embeds a search query and ranks catalog images by cosine similarity,
standing in for an Amazon OpenSearch Service k-NN search (not available on floci)."""
import json
import os

import boto3
from embeddings import cosine_similarity, embed_text

TABLE_NAME = os.environ["TABLE_NAME"]
REGION = os.environ.get("REGION", "us-east-1")
ENDPOINT_URL = "http://localhost:4566"

TOP_N = 5

dynamodb = boto3.resource(
    "dynamodb",
    region_name=REGION,
    endpoint_url=ENDPOINT_URL,
    aws_access_key_id="test",
    aws_secret_access_key="test",
)
table = dynamodb.Table(TABLE_NAME)


def lambda_handler(event, context):
    query = (event.get("queryStringParameters") or {}).get("q", "").strip()

    if not query:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Query parameter 'q' is required."}),
        }

    query_embedding = embed_text(query)

    scan_kwargs = {"ProjectionExpression": "imageKey, labels, embedding"}
    items = []
    while True:
        response = table.scan(**scan_kwargs)
        items.extend(response.get("Items", []))
        if "LastEvaluatedKey" not in response:
            break
        scan_kwargs["ExclusiveStartKey"] = response["LastEvaluatedKey"]

    ranked = []
    for item in items:
        embedding = [float(value) for value in item.get("embedding", [])]
        if not embedding:
            continue

        score = cosine_similarity(query_embedding, embedding)
        ranked.append({"imageKey": item["imageKey"], "labels": item.get("labels", []), "score": score})

    ranked.sort(key=lambda result: result["score"], reverse=True)

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"query": query, "results": ranked[:TOP_N]}),
    }
