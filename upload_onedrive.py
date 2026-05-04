import os
import json
import time
import requests
from auth import get_token

# Load config.json
with open("config.json", "r") as f:
    config = json.load(f)

ONEDRIVE_ROOT = config["folder_root"]  # e.g. "/ThreatDetections"
GRAPH_BASE = "https://graph.microsoft.com/v1.0"


def build_onedrive_path(local_path: str) -> str:
    """
    Build the OneDrive path from the local path.
    Example:
      local: screenshots/2026-04-13/img1.jpg
      drive: /ThreatDetections/2026-04-13/img1.jpg
    """
    date_folder = os.path.basename(os.path.dirname(local_path))
    filename = os.path.basename(local_path)
    return f"{ONEDRIVE_ROOT}/{date_folder}/{filename}"


def onedrive_item_exists(onedrive_path: str) -> bool:
    """
    Returns True if an item exists at the given OneDrive path.
    onedrive_path should start with e.g. "/ThreatDetections/..."
    """
    token = get_token()
    url = f"{GRAPH_BASE}/me/drive/root:{onedrive_path}"
    headers = {"Authorization": f"Bearer {token}"}
    resp = requests.get(url, headers=headers)
    return resp.status_code == 200


def put_with_retries(url, headers, data, max_attempts=5, base_delay=1.0):
    """
    PUT with simple exponential backoff for transient failures.
    """
    attempt = 0
    last_resp = None

    while attempt < max_attempts:
        try:
            resp = requests.put(url, headers=headers, data=data, timeout=30)
            last_resp = resp

            # Success
            if resp.status_code in (200, 201):
                return resp

            # Permanent client error (except 429) -> don't retry
            if 400 <= resp.status_code < 500 and resp.status_code != 429:
                return resp

        except requests.RequestException:
            last_resp = None

        attempt += 1
        sleep_time = min(base_delay * (2 ** (attempt - 1)), 30)
        time.sleep(sleep_time)

    return last_resp


def upload_file_to_onedrive(local_path: str) -> dict:
    """
    Uploads a file to OneDrive while preserving the Pi's folder structure.
    Idempotent: skips if the file already exists.
    """
    local_path = os.path.abspath(local_path)

    if not os.path.exists(local_path):
        return {"error": "local_file_missing", "path": local_path}

    onedrive_path = build_onedrive_path(local_path)

    # Idempotency: skip if already exists
    if onedrive_item_exists(onedrive_path):
        return {
            "skipped": True,
            "reason": "already_exists",
            "onedrive_path": onedrive_path,
            "local_path": local_path,
        }

    token = get_token()
    upload_url = f"{GRAPH_BASE}/me/drive/root:{onedrive_path}:/content"

    with open(local_path, "rb") as f:
        file_bytes = f.read()

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/octet-stream",
    }

    resp = put_with_retries(upload_url, headers, file_bytes)

    if resp is None:
        return {
            "error": "no_response",
            "onedrive_path": onedrive_path,
            "local_path": local_path,
        }

    try:
        data = resp.json()
    except Exception:
        data = {"raw_text": resp.text}

    data["status_code"] = resp.status_code
    data["onedrive_path"] = onedrive_path
    data["local_path"] = local_path
    return data
