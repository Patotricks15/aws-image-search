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

<div style="margin: 1.5rem 0 1rem; padding: 1.25rem; border: 1px solid rgba(45,49,66,0.14); border-radius: 12px; background: #f5f5f5; overflow-x: auto;">
<div style="display: flex; align-items: center; gap: 0.65rem; margin-bottom: 0.45rem;">
	<img src="../icons/Architecture-Group-Icons_07312026/AWS-Cloud-logo_32.svg" alt="AWS cloud icon" style="width: 30px; height: 30px; display: block;" />
	<div style="font-family: 'Geist Mono', ui-monospace, monospace; font-size: 0.72rem; letter-spacing: 0.16em; text-transform: uppercase; color: #4f5d75;">AWS Architecture</div>
</div>
<div style="font-family: 'Instrument Serif', Georgia, serif; font-size: 1.85rem; line-height: 1.1; color: #2d3142; margin-bottom: 0.35rem;">Image Search</div>
<div style="font-family: 'Geist Mono', ui-monospace, monospace; font-size: 0.72rem; letter-spacing: 0.14em; text-transform: uppercase; color: #4f5d75; margin-bottom: 1rem;">Rekognition labels every upload, Hugging Face embeds labels and queries, and both lanes read/write the same DynamoDB catalog</div>

<table style="width: 100%; min-width: 1100px; border-collapse: collapse; table-layout: fixed;">
	<tr>
		<td colspan="3"></td>
		<td style="text-align: center; padding-bottom: 0.3rem;">
			<div style="background: #ffffff; border: 1px solid rgba(45,49,66,0.18); border-radius: 12px; padding: 0.5rem 0.7rem; display: inline-flex; align-items: center; gap: 0.4rem;">
				<img src="../icons/Architecture-Service-Icons_07312026/Arch_Artificial-Intelligence/48/Arch_Amazon-Rekognition_48.svg" alt="Rekognition icon" style="width: 26px; height: 26px; display: block;" />
				<div style="font-family: 'Geist Mono', ui-monospace, monospace; font-size: 0.62rem; color: #2d3142; font-weight: 600;">Rekognition</div>
			</div>
		</td>
		<td></td>
		<td style="text-align: center; padding-bottom: 0.3rem;">
			<div style="background: #ffffff; border: 1px solid rgba(45,49,66,0.18); border-radius: 12px; padding: 0.5rem 0.7rem; display: inline-flex; align-items: center; gap: 0.4rem;">
				<img src="../icons/Category-Icons_07312026/Arch-Category_48/Arch-Category_Artificial-Intelligence_48.svg" alt="Hugging Face icon" style="width: 26px; height: 26px; display: block;" />
				<div style="font-family: 'Geist Mono', ui-monospace, monospace; font-size: 0.62rem; color: #2d3142; font-weight: 600;">🤗 Hugging Face</div>
			</div>
		</td>
		<td></td>
	</tr>
	<tr>
		<td colspan="3"></td>
		<td style="text-align: center; padding: 0.05rem 0;">
			<div style="width: 1px; height: 18px; background: #eb6c36; margin: 0 auto; position: relative;">
				<div style="position: absolute; top: -1px; left: -4px; width: 0; height: 0; border-bottom: 7px solid #eb6c36; border-left: 4px solid transparent; border-right: 4px solid transparent;"></div>
				<div style="position: absolute; bottom: -1px; left: -4px; width: 0; height: 0; border-top: 7px solid #eb6c36; border-left: 4px solid transparent; border-right: 4px solid transparent;"></div>
			</div>
		</td>
		<td></td>
		<td style="text-align: center; padding: 0.05rem 0;">
			<div style="width: 1px; height: 18px; background: #eb6c36; margin: 0 auto; position: relative;">
				<div style="position: absolute; top: -1px; left: -4px; width: 0; height: 0; border-bottom: 7px solid #eb6c36; border-left: 4px solid transparent; border-right: 4px solid transparent;"></div>
				<div style="position: absolute; bottom: -1px; left: -4px; width: 0; height: 0; border-top: 7px solid #eb6c36; border-left: 4px solid transparent; border-right: 4px solid transparent;"></div>
			</div>
		</td>
		<td></td>
	</tr>
	<tr>
		<td style="vertical-align: middle; width: 13%; padding: 0 0.3rem;">
			<div style="background: #ffffff; border: 1px solid rgba(45,49,66,0.18); border-radius: 12px; padding: 0.7rem; text-align: center;">
				<div style="display: flex; justify-content: center; margin-bottom: 0.45rem;">
					<img src="../icons/Resource-Icons_07312026/Res_Storage/Res_Amazon-Simple-Storage-Service_Bucket_48.svg" alt="S3 icon" style="width: 30px; height: 30px; display: block;" />
				</div>
				<div style="display: inline-block; font-family: 'Geist Mono', ui-monospace, monospace; font-size: 0.58rem; letter-spacing: 0.06em; color: #4f5d75; border: 1px solid rgba(79,93,117,0.35); border-radius: 4px; padding: 0.06rem 0.28rem; margin-bottom: 0.2rem;">S3</div>
				<div style="font-family: 'Geist', system-ui, sans-serif; font-size: 0.8rem; font-weight: 600; color: #2d3142;">Images Bucket</div>
			</div>
		</td>
		<td style="vertical-align: middle; width: 3.5%; text-align: center;">
			<div style="height: 1px; background: #eb6c36; position: relative;"><div style="position: absolute; right: -1px; top: -4px; width: 0; height: 0; border-left: 8px solid #eb6c36; border-top: 5px solid transparent; border-bottom: 5px solid transparent;"></div></div>
		</td>
		<td style="vertical-align: middle; width: 12%; padding: 0 0.3rem;">
			<div style="background: #ffffff; border: 1px solid rgba(45,49,66,0.18); border-radius: 12px; padding: 0.7rem; text-align: center;">
				<div style="display: flex; justify-content: center; margin-bottom: 0.45rem;">
					<img src="../icons/Resource-Icons_07312026/Res_Application-Integration/Res_Amazon-Simple-Notification-Service_Topic_48.svg" alt="SNS icon" style="width: 30px; height: 30px; display: block;" />
				</div>
				<div style="display: inline-block; font-family: 'Geist Mono', ui-monospace, monospace; font-size: 0.58rem; letter-spacing: 0.06em; color: #4f5d75; border: 1px solid rgba(79,93,117,0.35); border-radius: 4px; padding: 0.06rem 0.28rem; margin-bottom: 0.2rem;">SNS</div>
				<div style="font-family: 'Geist', system-ui, sans-serif; font-size: 0.8rem; font-weight: 600; color: #2d3142;">Image Uploaded</div>
			</div>
		</td>
		<td style="vertical-align: middle; width: 3.5%; text-align: center;">
			<div style="height: 1px; background: #eb6c36; position: relative;"><div style="position: absolute; right: -1px; top: -4px; width: 0; height: 0; border-left: 8px solid #eb6c36; border-top: 5px solid transparent; border-bottom: 5px solid transparent;"></div></div>
		</td>
		<td style="vertical-align: middle; width: 12%; padding: 0 0.3rem;">
			<div style="background: #ffffff; border: 1px solid rgba(45,49,66,0.18); border-radius: 12px; padding: 0.7rem; text-align: center;">
				<div style="display: flex; justify-content: center; margin-bottom: 0.45rem;">
					<img src="../icons/Resource-Icons_07312026/Res_Application-Integration/Res_Amazon-Simple-Queue-Service_Queue_48.svg" alt="SQS icon" style="width: 28px; height: 28px; display: block;" />
				</div>
				<div style="display: inline-block; font-family: 'Geist Mono', ui-monospace, monospace; font-size: 0.58rem; letter-spacing: 0.06em; color: #4f5d75; border: 1px solid rgba(79,93,117,0.35); border-radius: 4px; padding: 0.06rem 0.28rem; margin-bottom: 0.2rem;">SQS</div>
				<div style="font-family: 'Geist', system-ui, sans-serif; font-size: 0.8rem; font-weight: 600; color: #2d3142;">Labeling Queue</div>
			</div>
		</td>
		<td style="vertical-align: middle; width: 3.5%; text-align: center;">
			<div style="height: 1px; background: #eb6c36; position: relative;"><div style="position: absolute; right: -1px; top: -4px; width: 0; height: 0; border-left: 8px solid #eb6c36; border-top: 5px solid transparent; border-bottom: 5px solid transparent;"></div></div>
		</td>
		<td style="vertical-align: middle; width: 12%; padding: 0 0.3rem;">
			<div style="background: #ffffff; border: 1px solid rgba(45,49,66,0.18); border-radius: 12px; padding: 0.7rem; text-align: center;">
				<div style="display: flex; justify-content: center; margin-bottom: 0.45rem;">
					<img src="../icons/Architecture-Service-Icons_07312026/Arch_Compute/64/Arch_AWS-Lambda_64.svg" alt="Lambda icon" style="width: 30px; height: 30px; display: block;" />
				</div>
				<div style="display: inline-block; font-family: 'Geist Mono', ui-monospace, monospace; font-size: 0.58rem; letter-spacing: 0.06em; color: #4f5d75; border: 1px solid rgba(79,93,117,0.35); border-radius: 4px; padding: 0.06rem 0.28rem; margin-bottom: 0.2rem;">LAMBDA</div>
				<div style="font-family: 'Geist', system-ui, sans-serif; font-size: 0.8rem; font-weight: 600; color: #2d3142;">label_images</div>
			</div>
		</td>
		<td style="vertical-align: middle; width: 3.5%; text-align: center;">
			<div style="height: 1px; background: #eb6c36; position: relative;"><div style="position: absolute; right: -1px; top: -4px; width: 0; height: 0; border-left: 8px solid #eb6c36; border-top: 5px solid transparent; border-bottom: 5px solid transparent;"></div></div>
		</td>
		<td style="vertical-align: middle; width: 12%; padding: 0 0.3rem;">
			<div style="background: #ffffff; border: 1px solid rgba(45,49,66,0.18); border-radius: 12px; padding: 0.7rem; text-align: center;">
				<div style="display: flex; justify-content: center; margin-bottom: 0.45rem;">
					<img src="../icons/Resource-Icons_07312026/Res_Application-Integration/Res_Amazon-Simple-Queue-Service_Queue_48.svg" alt="SQS icon" style="width: 28px; height: 28px; display: block;" />
				</div>
				<div style="display: inline-block; font-family: 'Geist Mono', ui-monospace, monospace; font-size: 0.58rem; letter-spacing: 0.06em; color: #4f5d75; border: 1px solid rgba(79,93,117,0.35); border-radius: 4px; padding: 0.06rem 0.28rem; margin-bottom: 0.2rem;">SQS</div>
				<div style="font-family: 'Geist', system-ui, sans-serif; font-size: 0.8rem; font-weight: 600; color: #2d3142;">Indexing Queue</div>
			</div>
		</td>
		<td style="vertical-align: middle; width: 3.5%; text-align: center;">
			<div style="height: 1px; background: #eb6c36; position: relative;"><div style="position: absolute; right: -1px; top: -4px; width: 0; height: 0; border-left: 8px solid #eb6c36; border-top: 5px solid transparent; border-bottom: 5px solid transparent;"></div></div>
		</td>
		<td style="vertical-align: middle; width: 12%; padding: 0 0.3rem;">
			<div style="background: #ffffff; border: 1px solid rgba(45,49,66,0.18); border-radius: 12px; padding: 0.7rem; text-align: center;">
				<div style="display: flex; justify-content: center; margin-bottom: 0.45rem;">
					<img src="../icons/Architecture-Service-Icons_07312026/Arch_Compute/64/Arch_AWS-Lambda_64.svg" alt="Lambda icon" style="width: 30px; height: 30px; display: block;" />
				</div>
				<div style="display: inline-block; font-family: 'Geist Mono', ui-monospace, monospace; font-size: 0.58rem; letter-spacing: 0.06em; color: #4f5d75; border: 1px solid rgba(79,93,117,0.35); border-radius: 4px; padding: 0.06rem 0.28rem; margin-bottom: 0.2rem;">LAMBDA</div>
				<div style="font-family: 'Geist', system-ui, sans-serif; font-size: 0.8rem; font-weight: 600; color: #2d3142;">index_image</div>
			</div>
		</td>
		<td rowspan="6" style="vertical-align: middle; width: 3.5%; text-align: center;">
			<div style="height: 1px; background: #eb6c36; position: relative;"><div style="position: absolute; right: -1px; top: -4px; width: 0; height: 0; border-left: 8px solid #eb6c36; border-top: 5px solid transparent; border-bottom: 5px solid transparent;"></div></div>
		</td>
		<td rowspan="6" style="vertical-align: middle; width: 12.5%; padding: 0 0.3rem;">
			<div style="background: #ffffff; border: 1px solid rgba(45,49,66,0.18); border-radius: 12px; padding: 0.85rem; text-align: center;">
				<div style="display: flex; justify-content: center; margin-bottom: 0.5rem;">
					<img src="../icons/Architecture-Service-Icons_07312026/Arch_Databases/48/Arch_Amazon-DynamoDB_48.svg" alt="DynamoDB icon" style="width: 34px; height: 34px; display: block;" />
				</div>
				<div style="display: inline-block; font-family: 'Geist Mono', ui-monospace, monospace; font-size: 0.6rem; letter-spacing: 0.06em; color: #4f5d75; border: 1px solid rgba(79,93,117,0.35); border-radius: 4px; padding: 0.08rem 0.3rem; margin-bottom: 0.25rem;">DYNAMODB</div>
				<div style="font-family: 'Geist', system-ui, sans-serif; font-size: 0.85rem; font-weight: 600; color: #2d3142;">Image Catalog</div>
				<div style="font-family: 'Geist Mono', ui-monospace, monospace; font-size: 0.65rem; color: #4f5d75; margin-top: 0.2rem;">labels + embedding</div>
			</div>
		</td>
	</tr>
	<tr>
		<td colspan="9" style="padding: 0.3rem 0;"></td>
	</tr>
	<tr>
		<td colspan="3"></td>
		<td></td>
		<td style="text-align: center; padding-bottom: 0.3rem;">
			<div style="background: #ffffff; border: 1px solid rgba(45,49,66,0.18); border-radius: 12px; padding: 0.5rem 0.7rem; display: inline-flex; align-items: center; gap: 0.4rem;">
				<img src="../icons/Category-Icons_07312026/Arch-Category_48/Arch-Category_Artificial-Intelligence_48.svg" alt="Hugging Face icon" style="width: 26px; height: 26px; display: block;" />
				<div style="font-family: 'Geist Mono', ui-monospace, monospace; font-size: 0.62rem; color: #2d3142; font-weight: 600;">🤗 Hugging Face</div>
			</div>
		</td>
	</tr>
	<tr>
		<td colspan="3"></td>
		<td></td>
		<td style="text-align: center; padding: 0.05rem 0;">
			<div style="width: 1px; height: 18px; background: #eb6c36; margin: 0 auto; position: relative;">
				<div style="position: absolute; top: -1px; left: -4px; width: 0; height: 0; border-bottom: 7px solid #eb6c36; border-left: 4px solid transparent; border-right: 4px solid transparent;"></div>
				<div style="position: absolute; bottom: -1px; left: -4px; width: 0; height: 0; border-top: 7px solid #eb6c36; border-left: 4px solid transparent; border-right: 4px solid transparent;"></div>
			</div>
		</td>
	</tr>
	<tr>
		<td style="vertical-align: middle; padding: 0 0.3rem;">
			<div style="background: #ffffff; border: 1px solid rgba(45,49,66,0.18); border-radius: 12px; padding: 0.7rem; text-align: center;">
				<div style="display: flex; justify-content: center; margin-bottom: 0.45rem;">
					<img src="../icons/Resource-Icons_07312026/Res_General-Icons/Res_48_Light/Res_Client_48_Light.svg" alt="Client icon" style="width: 28px; height: 28px; display: block; filter: invert(28%) sepia(9%) saturate(1077%) hue-rotate(176deg);" />
				</div>
				<div style="font-family: 'Geist', system-ui, sans-serif; font-size: 0.8rem; font-weight: 600; color: #2d3142;">Search Client</div>
			</div>
		</td>
		<td style="vertical-align: middle; text-align: center;">
			<div style="height: 1px; background: #eb6c36; position: relative;"><div style="position: absolute; right: -1px; top: -4px; width: 0; height: 0; border-left: 8px solid #eb6c36; border-top: 5px solid transparent; border-bottom: 5px solid transparent;"></div></div>
		</td>
		<td style="vertical-align: middle; padding: 0 0.3rem;">
			<div style="background: #ffffff; border: 1px solid rgba(45,49,66,0.18); border-radius: 12px; padding: 0.7rem; text-align: center;">
				<div style="display: flex; justify-content: center; margin-bottom: 0.45rem;">
					<img src="../icons/Resource-Icons_07312026/Res_Networking-Content-Delivery/Res_Amazon-API-Gateway_Endpoint_48.svg" alt="API Gateway icon" style="width: 30px; height: 30px; display: block;" />
				</div>
				<div style="display: inline-block; font-family: 'Geist Mono', ui-monospace, monospace; font-size: 0.58rem; letter-spacing: 0.06em; color: #4f5d75; border: 1px solid rgba(79,93,117,0.35); border-radius: 4px; padding: 0.06rem 0.28rem; margin-bottom: 0.2rem;">API GATEWAY</div>
				<div style="font-family: 'Geist', system-ui, sans-serif; font-size: 0.8rem; font-weight: 600; color: #2d3142;">GET /search</div>
			</div>
		</td>
		<td style="vertical-align: middle; text-align: center;">
			<div style="height: 1px; background: #eb6c36; position: relative;"><div style="position: absolute; right: -1px; top: -4px; width: 0; height: 0; border-left: 8px solid #eb6c36; border-top: 5px solid transparent; border-bottom: 5px solid transparent;"></div></div>
		</td>
		<td style="vertical-align: middle; padding: 0 0.3rem;">
			<div style="background: #ffffff; border: 1px solid rgba(45,49,66,0.18); border-radius: 12px; padding: 0.7rem; text-align: center;">
				<div style="display: flex; justify-content: center; margin-bottom: 0.45rem;">
					<img src="../icons/Architecture-Service-Icons_07312026/Arch_Compute/64/Arch_AWS-Lambda_64.svg" alt="Lambda icon" style="width: 30px; height: 30px; display: block;" />
				</div>
				<div style="display: inline-block; font-family: 'Geist Mono', ui-monospace, monospace; font-size: 0.58rem; letter-spacing: 0.06em; color: #4f5d75; border: 1px solid rgba(79,93,117,0.35); border-radius: 4px; padding: 0.06rem 0.28rem; margin-bottom: 0.2rem;">LAMBDA</div>
				<div style="font-family: 'Geist', system-ui, sans-serif; font-size: 0.8rem; font-weight: 600; color: #2d3142;">search_images</div>
			</div>
		</td>
		<td colspan="3"></td>
	</tr>
</table>

<div style="font-family: 'Geist', system-ui, sans-serif; font-size: 0.95rem; font-weight: 600; color: #2d3142; text-align: center; margin-top: 1rem;">AWS project: Rekognition labels every upload, Hugging Face embeds labels and queries, and DynamoDB plays the role Amazon OpenSearch Service would normally play</div>
</div>

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
