"""Run inside approved Blender's Python: encode and decode portable listening copies."""
from pathlib import Path
import json
import hashlib
import wave
import aud
import numpy as np

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'builds/music_pilot197'
REVIEWS=ROOT/'docs/evidence/card197/audio'
REVIEWS.mkdir(parents=True,exist_ok=True)
rows=[]
for folder in sorted(OUT.glob('[ABC]_*')):
    for source,target in [(folder/'preview.wav',REVIEWS/(folder.name+'.mp3')),
                          (folder/'repeat_3_passes.wav',folder/'repeat_3_passes.mp3')]:
        sound=aud.Sound.file(str(source))
        sound.write(str(target),44100,2,aud.FORMAT_S16,aud.CONTAINER_MP3,aud.CODEC_MP3,160000,16384)
        decoded=aud.Sound.file(str(target))
        decoded_path=folder/('decoded_preview.wav' if source.name=='preview.wav' else 'decoded_repeat.wav')
        values=np.asarray(decoded.data())
        # data() honors MP3 gapless metadata; streaming write() flushes extra buffer padding.
        with wave.open(str(decoded_path),'wb') as pcm:
            pcm.setnchannels(2); pcm.setsampwidth(2); pcm.setframerate(44100)
            pcm.writeframes(np.rint(np.clip(values,-1,1)*32767).astype('<i2').tobytes())
        row={'file':str(target.relative_to(ROOT)).replace('\\','/'),'bytes':target.stat().st_size,
             'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'decoded_frames':len(values),
             'decoded_peak':float(np.max(np.abs(values))),'decoded_channels':values.shape[1]}
        rows.append(row); print(json.dumps(row),flush=True)
(OUT/'encoded.json').write_text(json.dumps({'encoder':'Blender bundled Audaspace / MP3 160kbps','files':rows},indent=2)+'\n')
