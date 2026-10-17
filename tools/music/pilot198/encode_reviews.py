"""Approved Blender/Audaspace encoding; no new package or runtime asset."""
from pathlib import Path
import hashlib
import json
import wave
import aud
import numpy as np

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'builds/music_pilot198'
REVIEWS=ROOT/'docs/evidence/card198/audio'
REVIEWS.mkdir(parents=True,exist_ok=True)
rows=[]
for folder in sorted(OUT.glob('C[12]_*')):
    for source,target in [(folder/'preview.wav',REVIEWS/(folder.name+'.mp3')),
                          (folder/'repeat_3_passes.wav',folder/'repeat_3_passes.mp3')]:
        aud.Sound.file(str(source)).write(str(target),44100,2,aud.FORMAT_S16,aud.CONTAINER_MP3,aud.CODEC_MP3,160000,16384)
        values=np.asarray(aud.Sound.file(str(target)).data())
        decoded=folder/('decoded_preview.wav' if source.name=='preview.wav' else 'decoded_repeat.wav')
        with wave.open(str(decoded),'wb') as f:
            f.setnchannels(2); f.setsampwidth(2); f.setframerate(44100)
            f.writeframes(np.rint(np.clip(values,-1,1)*32767).astype('<i2').tobytes())
        row={'file':str(target.relative_to(ROOT)).replace('\\','/'),'bytes':target.stat().st_size,
             'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'decoded_frames':len(values),'decoded_peak':float(np.max(abs(values)))}
        rows.append(row); print(json.dumps(row),flush=True)
(OUT/'encoded.json').write_text(json.dumps({'encoder':'Blender bundled MP3 160kbps','files':rows},indent=2)+'\n')
