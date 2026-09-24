"""Generates docs/architecture.drawio for the Image Search project using drawpyo.

Run with: python3 scripts/generate_diagram.py

Uses AWS4 shapes that ship natively with every draw.io/diagrams.net renderer
(desktop, web, VS Code and GitHub's built-in .drawio viewer), so no external
shape library needs to be downloaded to open the file.
"""
import os

import drawpyo

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs")

AWS4_BASE = (
    "sketch=0;outlineConnect=0;fontColor=#232F3E;gradientColor=none;strokeColor=none;"
    "dashed=0;verticalLabelPosition=bottom;verticalAlign=top;align=center;html=1;"
    "fontSize=11;fontStyle=0;aspect=fixed;pointerEvents=1;"
)


def aws_style(shape_kind, icon_name, fill_color):
    """Builds an AWS4 resourceIcon/productIcon style string."""
    return (
        f"{AWS4_BASE}fillColor={fill_color};shape=mxgraph.aws4.{shape_kind};"
        + (f"resIcon=mxgraph.aws4.{icon_name};" if shape_kind == "resourceIcon" else f"prIcon=mxgraph.aws4.{icon_name};")
    )


def add_node(page, name, x, y, shape_kind, icon_name, fill_color, width=64, height=64):
    node = drawpyo.diagram.Object(page=page, value=name)
    node.position = (x, y)
    node.geometry.width = width
    node.geometry.height = height
    node.apply_style_string(aws_style(shape_kind, icon_name, fill_color))
    return node


def add_note(page, text, x, y, width=140, height=30):
    note = drawpyo.diagram.Object(page=page, value=text)
    note.position = (x, y)
    note.geometry.width = width
    note.geometry.height = height
    note.apply_style_string(
        "rounded=1;whiteSpace=wrap;html=1;fillColor=#FFF2CC;strokeColor=#D6B656;"
        "fontSize=10;fontColor=#7F6000;align=center;"
    )
    return note


def add_edge(page, source, target, label=None):
    edge = drawpyo.diagram.Edge(page=page, source=source, target=target, label=label)
    edge.waypoints = "orthogonal"
    edge.endArrow = "block"
    edge.startArrow = "none"
    edge.strokeColor = "#545B64"
    return edge


def build_diagram():
    file = drawpyo.File()
    file.file_name = "architecture.drawio"
    file.file_path = OUTPUT_DIR

    page = drawpyo.Page(file=file)
    page.name = "Image Search"

    # Storage / trigger row
    images_bucket = add_node(page, "Images Bucket\n(S3)", 40, 80, "resourceIcon", "bucket", "#7AA116")
    image_uploaded = add_node(page, "Image Uploaded\n(SNS)", 200, 80, "resourceIcon", "sns", "#E7157B")
    labeling_queue = add_node(page, "Labeling Queue\n(SQS)", 360, 80, "resourceIcon", "sqs", "#E7157B")
    label_images = add_node(page, "label_images\n(Lambda)", 520, 80, "resourceIcon", "lambda_function", "#ED7100")
    rekognition = add_node(page, "Rekognition", 520, -40, "resourceIcon", "rekognition_2", "#01A88D")

    indexing_queue = add_node(page, "Indexing Queue\n(SQS)", 680, 80, "resourceIcon", "sqs", "#E7157B")
    index_image = add_node(page, "index_image\n(Lambda)", 840, 80, "resourceIcon", "lambda_function", "#ED7100")
    hugging_face_1 = add_note(page, "\U0001F917 Hugging Face\nembeddings API", 800, -50, width=160)

    image_catalog = add_node(page, "Image Catalog\n(DynamoDB)", 1000, 80, "resourceIcon", "dynamodb", "#C925D1", height=80)

    # Search lane
    search_client = add_node(page, "Search Client", 40, 260, "resourceIcon", "client", "#232F3E")
    api_gateway = add_node(page, "GET /search\n(API Gateway)", 200, 260, "resourceIcon", "api_gateway", "#E7157B")
    search_images = add_node(page, "search_images\n(Lambda)", 360, 260, "resourceIcon", "lambda_function", "#ED7100")
    hugging_face_2 = add_note(page, "\U0001F917 Hugging Face\nembeddings API", 320, 360, width=160)

    add_edge(page, images_bucket, image_uploaded)
    add_edge(page, image_uploaded, labeling_queue)
    add_edge(page, labeling_queue, label_images)
    add_edge(page, label_images, rekognition, "detect_labels")
    add_edge(page, label_images, indexing_queue, "sqs.send_message")
    add_edge(page, indexing_queue, index_image)
    add_edge(page, index_image, hugging_face_1, "embed labels")
    add_edge(page, label_images, image_catalog, "put_item")
    add_edge(page, index_image, image_catalog, "update_item (embedding)")

    add_edge(page, search_client, api_gateway)
    add_edge(page, api_gateway, search_images)
    add_edge(page, search_images, hugging_face_2, "embed query")
    add_edge(page, search_images, image_catalog, "scan + cosine similarity")

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    file.write()
    print(f"Wrote {os.path.join(OUTPUT_DIR, file.file_name)}")


if __name__ == "__main__":
    build_diagram()
