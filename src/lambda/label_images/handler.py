"""label_images: runs Rekognition label detection on an uploaded image and queues it for indexing."""
import json
import os
import urllib.parse
from datetime import datetime, timezone

import boto3

TABLE_NAME = os.environ["TABLE_NAME"]
INDEXING_QUEUE_URL = os.environ["INDEXING_QUEUE_URL"]
REGION = os.environ.get("REGION", "us-east-1")
ENDPOINT_URL = "http://localhost:4566"

session_kwargs = {
    "region_name": REGION,
    "endpoint_url": ENDPOINT_URL,
    "aws_access_key_id": "test",
    "aws_secret_access_key": "test",
}

rekognition = boto3.client("rekognition", **session_kwargs)
sqs = boto3.client("sqs", **session_kwargs)
dynamodb = boto3.resource("dynamodb", **session_kwargs)
table = dynamodb.Table(TABLE_NAME)

MAX_LABELS = 10
MIN_CONFIDENCE = 70


def lambda_handler(event, context):
    labeled = []

    for record in event.get("Records", []):
        s3_event = json.loads(record["body"])

        for s3_record in s3_event.get("Records", []):
            bucket = s3_record["s3"]["bucket"]["name"]
            key = urllib.parse.unquote_plus(s3_record["s3"]["object"]["key"])

            response = rekognition.detect_labels(
                Image={"S3Object": {"Bucket": bucket, "Name": key}},
                MaxLabels=MAX_LABELS,
                MinConfidence=MIN_CONFIDENCE,
            )
            labels = [label["Name"] for label in response.get("Labels", [])]

            table.put_item(
                Item={
                    "imageKey": key,
                    "labels": labels,
                    "labeledAt": datetime.now(timezone.utc).isoformat(),
                }
            )

            sqs.send_message(
                QueueUrl=INDEXING_QUEUE_URL,
                MessageBody=json.dumps({"imageKey": key}),
            )
            labeled.append(key)

    return {"labeled": labeled}
