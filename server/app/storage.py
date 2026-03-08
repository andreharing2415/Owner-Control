import os
import re
from typing import BinaryIO
from urllib.parse import unquote, urlparse


def _use_gcs() -> bool:
    """Use Google Cloud Storage when S3_ENDPOINT_URL is not set (production on GCP)."""
    return not os.getenv("S3_ENDPOINT_URL")


# ── Google Cloud Storage (production) ────────────────────────────────────────

def _get_gcs_client():
    from google.cloud import storage
    return storage.Client()


def _upload_gcs(bucket_name: str, object_key: str, file_obj: BinaryIO, content_type: str | None) -> str:
    client = _get_gcs_client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(object_key)
    blob.upload_from_file(file_obj, content_type=content_type)
    return f"https://storage.googleapis.com/{bucket_name}/{object_key}"


def _download_gcs(bucket_name: str, object_key: str) -> bytes:
    client = _get_gcs_client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(object_key)
    return blob.download_as_bytes()


def _ensure_bucket_gcs(bucket_name: str) -> None:
    client = _get_gcs_client()
    bucket = client.bucket(bucket_name)
    if not bucket.exists():
        client.create_bucket(bucket_name, location=os.getenv("GCS_LOCATION", "southamerica-east1"))


# ── S3 / MinIO (local development) ──────────────────────────────────────────

def _get_s3_client():
    import boto3
    return boto3.client(
        "s3",
        endpoint_url=os.getenv("S3_ENDPOINT_URL"),
        aws_access_key_id=os.getenv("S3_ACCESS_KEY"),
        aws_secret_access_key=os.getenv("S3_SECRET_KEY"),
        region_name=os.getenv("S3_REGION", "us-east-1"),
    )


def _upload_s3(bucket_name: str, object_key: str, file_obj: BinaryIO, content_type: str | None) -> str:
    client = _get_s3_client()
    extra_args = {}
    if content_type:
        extra_args["ContentType"] = content_type
    client.upload_fileobj(file_obj, bucket_name, object_key, ExtraArgs=extra_args)
    endpoint = os.getenv("S3_PUBLIC_URL") or os.getenv("S3_ENDPOINT_URL")
    return f"{endpoint.rstrip('/')}/{bucket_name}/{object_key}"


def _download_s3(bucket_name: str, object_key: str) -> bytes:
    client = _get_s3_client()
    response = client.get_object(Bucket=bucket_name, Key=object_key)
    return response["Body"].read()


def _ensure_bucket_s3(bucket_name: str) -> None:
    from botocore.exceptions import ClientError
    client = _get_s3_client()
    try:
        client.head_bucket(Bucket=bucket_name)
    except ClientError:
        client.create_bucket(Bucket=bucket_name)


# ── Public API (unchanged signatures) ───────────────────────────────────────

def ensure_bucket(bucket_name: str) -> None:
    if _use_gcs():
        _ensure_bucket_gcs(bucket_name)
    else:
        _ensure_bucket_s3(bucket_name)


def upload_file(bucket_name: str, object_key: str, file_obj: BinaryIO, content_type: str | None) -> str:
    if _use_gcs():
        return _upload_gcs(bucket_name, object_key, file_obj, content_type)
    return _upload_s3(bucket_name, object_key, file_obj, content_type)


def download_file(bucket_name: str, object_key: str) -> bytes:
    if _use_gcs():
        return _download_gcs(bucket_name, object_key)
    return _download_s3(bucket_name, object_key)


def extract_object_key(arquivo_url: str, bucket: str) -> str:
    """Extract the GCS/S3 object key from a stored file URL.

    Handles multiple URL formats:
    - GCS: https://storage.googleapis.com/{bucket}/{key}
    - Supabase S3: https://xxx.supabase.co/storage/v1/object/public/{bucket}/{key}
    - MinIO S3: http://localhost:9000/{bucket}/{key}
    - Fallback: regex search for known path patterns (projetos/*, evidencias/*)
    """
    url = unquote(arquivo_url)

    prefix = f"/{bucket}/"
    idx = url.find(prefix)
    if idx != -1:
        return url[idx + len(prefix):]

    parsed = urlparse(url)
    path = parsed.path.lstrip("/")
    if path.startswith(f"{bucket}/"):
        return path[len(f"{bucket}/"):]

    match = re.search(r"(projetos/[0-9a-f-]+/.+)$", url)
    if match:
        return match.group(1)
    match = re.search(r"(evidencias/.+)$", url)
    if match:
        return match.group(1)
    match = re.search(r"(analises-visuais/.+)$", url)
    if match:
        return match.group(1)

    raise ValueError(f"Nao foi possivel extrair object_key da URL '{arquivo_url}' com bucket '{bucket}'")


def download_by_url(url: str, bucket_name: str, object_key: str) -> bytes:
    """Download file: try current storage first, fall back to direct HTTP GET."""
    try:
        return download_file(bucket_name, object_key)
    except Exception:
        from urllib.request import urlopen, Request
        req = Request(url, headers={"User-Agent": "ObraMaster/1.0"})
        with urlopen(req, timeout=60) as resp:
            return resp.read()
