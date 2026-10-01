#!/usr/bin/env python3
"""Uploads every PNG in assets/icons to Roblox and saves their IDs.

Uses Roblox Open Cloud (no extra Python packages needed). Writes the asset
IDs into src/shared/Icons.json; rebuild the place afterwards and the icons
appear everywhere in the game.

You need:
  * an Open Cloud API key with the "Assets" API, Read and Write
    (create.roblox.com > Open Cloud > API Keys > Create API Key)
  * your Roblox user ID (the number in your profile URL), or a group ID if
    the game belongs to a group

Usage:
    python3 tools/upload_icons.py --api-key YOUR_KEY --user-id 12345678
    python3 tools/upload_icons.py --api-key YOUR_KEY --group-id 987654
Icons that already have an ID in Icons.json are skipped (use --force to redo).
"""

from __future__ import annotations

import argparse
import json
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ICON_DIR = ROOT / "assets" / "icons"
ICONS_JSON = ROOT / "src" / "shared" / "Icons.json"
API = "https://apis.roblox.com/assets/v1"


def request(method: str, url: str, api_key: str, body: bytes | None = None, content_type: str | None = None) -> dict:
    headers = {"x-api-key": api_key}
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            return json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as error:
        raise SystemExit(f"Roblox said {error.code}: {error.read().decode(errors='replace')}") from None


def upload(path: Path, api_key: str, creator: dict) -> int:
    boundary = uuid.uuid4().hex
    meta = {
        "assetType": "Decal",
        "displayName": "Reef Keepers " + path.stem.replace("_", " "),
        "description": "Reef Keepers UI icon",
        "creationContext": {"creator": creator},
    }
    parts = [
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n{json.dumps(meta)}\r\n".encode(),
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{path.name}\"\r\n"
        "Content-Type: image/png\r\n\r\n".encode() + path.read_bytes() + b"\r\n",
        f"--{boundary}--\r\n".encode(),
    ]
    operation = request("POST", f"{API}/assets", api_key, b"".join(parts), f"multipart/form-data; boundary={boundary}")
    # Uploads finish asynchronously (moderation); poll the operation.
    for _ in range(60):
        if operation.get("done"):
            return int(operation["response"]["assetId"])
        time.sleep(2)
        operation = request("GET", f"{API}/{operation['path']}", api_key)
    raise SystemExit(f"Timed out waiting for {path.name}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--api-key", required=True)
    who = parser.add_mutually_exclusive_group(required=True)
    who.add_argument("--user-id")
    who.add_argument("--group-id")
    parser.add_argument("--force", action="store_true", help="re-upload icons that already have an ID")
    args = parser.parse_args()

    creator = {"userId": str(args.user_id)} if args.user_id else {"groupId": str(args.group_id)}
    ids = json.loads(ICONS_JSON.read_text())
    for path in sorted(ICON_DIR.glob("*.png")):
        if ids.get(path.stem) and not args.force:
            print(f"skip   {path.stem} (already {ids[path.stem]})")
            continue
        ids[path.stem] = upload(path, args.api_key, creator)
        print(f"upload {path.stem} -> {ids[path.stem]}")
        ICONS_JSON.write_text(json.dumps(ids, indent="\t") + "\n")  # save as we go
    print(f"\nDone. IDs saved to {ICONS_JSON.relative_to(ROOT)}. Rebuild with: rojo build -o ReefKeepers.rbxl")


if __name__ == "__main__":
    main()
