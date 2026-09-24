"""embeddings: thin client for the Hugging Face Inference API, used as a lightweight
stand-in for Amazon OpenSearch Service semantic search (not available on floci)."""
import json
import os
import urllib.request

HF_API_TOKEN = os.environ.get("HF_API_TOKEN", "")
HF_MODEL_ID = os.environ["HF_MODEL_ID"]
HF_API_URL = f"https://api-inference.huggingface.co/models/{HF_MODEL_ID}"


def embed_text(text: str) -> list[float]:
    """Returns a single sentence-level embedding vector for the given text."""
    request = urllib.request.Request(
        HF_API_URL,
        data=json.dumps({"inputs": text, "options": {"wait_for_model": True}}).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {HF_API_TOKEN}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    with urllib.request.urlopen(request, timeout=25) as response:
        payload = json.loads(response.read().decode("utf-8"))

    return _mean_pool(payload)


def _mean_pool(payload) -> list[float]:
    """The feature-extraction task returns per-token vectors; average them into one."""
    if not payload:
        return []

    # A single sentence returns a list of token vectors: [[...], [...], ...].
    if isinstance(payload[0], list):
        dims = len(payload[0])
        sums = [0.0] * dims
        for token_vector in payload:
            for i, value in enumerate(token_vector):
                sums[i] += value
        return [value / len(payload) for value in sums]

    # Some models already return a single pooled vector: [...].
    return list(payload)


def cosine_similarity(a: list[float], b: list[float]) -> float:
    if not a or not b or len(a) != len(b):
        return 0.0

    dot = sum(x * y for x, y in zip(a, b))
    norm_a = sum(x * x for x in a) ** 0.5
    norm_b = sum(y * y for y in b) ** 0.5

    if norm_a == 0 or norm_b == 0:
        return 0.0

    return dot / (norm_a * norm_b)
