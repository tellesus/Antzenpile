"""Encode the suite listening preview with existing approved Blender/Audaspace."""
from pathlib import Path
import wave
import json
import hashlib
import aud
import numpy as np

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'builds/music_suite199'
REVIEW=ROOT/'docs/evidence/card199/audio'
REVIEW.mkdir(parents=True,exist_ok=True)
rows=[]
for name,target in [('WarmCurrent_Layered',REVIEW/'WarmCurrent_Layered.mp3'),
                    ('Technical_CueOverlap',OUT/'Technical_CueOverlap.mp3')]:
    source=OUT/(name+'.wav')
    aud.Sound.file(str(source)).write(str(target),44100,2,aud.FORMAT_S16,aud.CONTAINER_MP3,aud.CODEC_MP3,160000,16384)
    pcm=np.asarray(aud.Sound.file(str(target)).data())
    with wave.open(str(OUT/(name+'_decoded.wav')),'wb') as f:
        f.setnchannels(2); f.setsampwidth(2); f.setframerate(44100)
        f.writeframes(np.rint(np.clip(pcm,-1,1)*32767).astype('<i2').tobytes())
    row={'file':str(target.relative_to(ROOT)).replace('\\','/'),'bytes':target.stat().st_size,
         'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'decoded_frames':len(pcm),
         'decoded_peak':float(np.max(abs(pcm)))}
    rows.append(row); print(json.dumps(row),flush=True)
(OUT/'encoded.json').write_text(json.dumps({'encoder':'Blender bundled MP3 160kbps','files':rows},indent=2)+'\n')
