"""Fetch only the two approved, checksum-pinned CC0 production sources."""
from pathlib import Path
import hashlib
import json
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[3]
CACHE = ROOT / '.godot/card195/sources'

def fetch():
    CACHE.mkdir(parents=True, exist_ok=True)
    for item in json.loads(Path(__file__).with_name('source_manifest.json').read_text()):
        path = CACHE / item['file']
        if not path.exists():
            req = urllib.request.Request(item['url'], headers={'User-Agent': 'Antzenpile offline asset authoring'})
            with urllib.request.urlopen(req, timeout=60) as response:
                data = response.read()
            if hashlib.sha256(data).hexdigest() != item['sha256']:
                raise ValueError('Source changed: ' + item['file'])
            path.write_bytes(data)
        if hashlib.sha256(path.read_bytes()).hexdigest() != item['sha256']:
            raise ValueError('Source checksum mismatch: ' + item['file'])
    with zipfile.ZipFile(CACHE / 'Ground054_1K-PNG.zip') as archive:
        for entry in archive.infolist():
            if not (CACHE / entry.filename).resolve().is_relative_to(CACHE.resolve()):
                raise ValueError('Archive path escapes cache')
        archive.extractall(CACHE)
    print('Two CC0 sources verified; ambientCG maps extracted.')

if __name__ == '__main__':
    fetch()
