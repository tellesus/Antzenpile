"""Fetch only the pinned CC0 source recordings; authoring, never runtime."""
from concurrent.futures import ThreadPoolExecutor
from hashlib import sha256
import json
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parent


def fetch(row):
    target = ROOT / "samples" / row["file"]
    if target.exists() and sha256(target.read_bytes()).hexdigest() == row["sha256"]:
        return
    payload = urlopen(row["url"], timeout=30).read()
    if sha256(payload).hexdigest() != row["sha256"]:
        raise ValueError("Upstream sample checksum mismatch: " + row["file"])
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(payload)


if __name__ == "__main__":
    manifest = json.loads((ROOT / "sample_manifest.json").read_text())
    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(fetch, manifest["samples"]))
    print("Seven CC0 sources ready; all SHA-256 checksums verified.")
