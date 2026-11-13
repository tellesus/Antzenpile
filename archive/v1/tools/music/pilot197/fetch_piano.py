"""Fetch only the selected CC0 soft Kawai notes; pin the existing VCSL tree."""
from pathlib import Path
import hashlib
import json
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[3]
TREE = 'dfcf4a4918771eee884b96ad4493de82ef84daf6'
NOTES = {'C3':48, 'E3':52, 'G#3':56, 'C4':60, 'E4':64, 'G#4':68, 'C5':72, 'D#5':75}
CACHE = ROOT / '.godot/card197/sources'
MANIFEST = Path(__file__).with_name('sources.json')


def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent':'Antzenpile-authoring'}),timeout=60).read()


def main():
    CACHE.mkdir(parents=True,exist_ok=True)
    existing = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else None
    if existing:
        rows = existing['samples']
    else:
        tree = json.loads(get(f'https://api.github.com/repos/sgossner/VCSL/git/trees/{TREE}?recursive=1'))
        by_path = {r['path']:r for r in tree['tree']}
        rows=[]
        for note,midi in NOTES.items():
            path=f'Chordophones/Zithers/Grand Piano, Kawai/Sustains/GPiano_sus_{note}_v1_rr1_Player.wav'
            row=by_path[path]
            rows.append({'file':f'piano_{midi}.wav','midi':midi,'source_path':path,'git_blob':row['sha'],'bytes':row['size'],
                         'url':f'https://raw.githubusercontent.com/sgossner/VCSL/{TREE}/'+urllib.parse.quote(path)})
    for row in rows:
        path=CACHE/row['file']
        data=path.read_bytes() if path.exists() else get(row['url'])
        blob=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
        digest=hashlib.sha256(data).hexdigest()
        if blob != row['git_blob'] or len(data) != row['bytes'] or ('sha256' in row and digest != row['sha256']):
            raise ValueError('Source mismatch: '+row['file'])
        path.write_bytes(data); row['sha256']=digest
        print(row['file'],len(data),flush=True)
    MANIFEST.write_text(json.dumps({'source':'https://github.com/sgossner/VCSL','upstream_tree':TREE,
        'author':'Sam Gossner / Versilian Studios','license':'CC0-1.0','samples':rows},indent=2)+'\n')


if __name__=='__main__': main()
