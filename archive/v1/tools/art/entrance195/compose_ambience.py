"""Process the licensed Freesound preview into a quiet seamless colony texture.

Blender's bundled Audaspace decodes the MP3; NumPy (existing authoring dependency)
does deterministic offline filtering/overlap. Only the resulting WAV ships.
"""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import wave
import numpy as np

ROOT=Path(__file__).resolve().parents[3]
CACHE=ROOT/'.godot/card195/sources'

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--blender',required=True);args=ap.parse_args()
    row=json.loads(Path(__file__).with_name('source_manifest.json').read_text())[1]
    assert hashlib.sha256((CACHE/'leaves.mp3').read_bytes()).hexdigest()==row['sha256']
    expr="import aud; aud.Sound(%r).write(%r,44100,2,aud.FORMAT_S16,aud.CONTAINER_WAV,aud.CODEC_PCM,0,4096)" % (str(CACHE/'leaves.mp3'),str(CACHE/'leaves.wav'))
    subprocess.run([args.blender,'-b','--factory-startup','--python-expr',expr],check=True)
    with wave.open(str(CACHE/'leaves.wav'),'rb') as f:
        sr=f.getframerate();assert sr==44100 and f.getnchannels()==2 and f.getsampwidth()==2
        raw=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(np.float64).reshape(-1,2)/32768
    # Strip DC, soften brittle leaf transients and remove low wind/handling rumble.
    raw-=raw.mean(axis=0)
    freq=np.fft.rfftfreq(len(raw),1/sr)
    response=(1-np.exp(-(freq/240)**4))*np.exp(-(freq/3800)**4)
    raw=np.fft.irfft(np.fft.rfft(raw,axis=0)*response[:,None],n=len(raw),axis=0)
    # Short windows form gently changing granular patter, never rhythmic footsteps
    # or signals of external creatures. Circular placement makes the loop seamless.
    length=sr*24;out=np.zeros((length,2));rng=np.random.default_rng(195)
    for i in range(70):
        count=int(sr*rng.uniform(.45,1.9));start=int(rng.integers(sr,len(raw)-count-sr))
        grain=raw[start:start+count].copy()
        gain=rng.uniform(.12,.35);pan=rng.uniform(-.65,.65)
        grain*=np.sin(np.linspace(0,np.pi,count))[:,None]**2*gain
        grain[:,0]*=np.sqrt((1-pan)/2);grain[:,1]*=np.sqrt((1+pan)/2)
        at=int(i*length/70+rng.uniform(-.1,.1)*sr)%length
        indices=(at+np.arange(count))%length;out[indices]+=grain
    # Smooth saturation retains a soft granular texture without startling peaks.
    out=np.tanh(out/(np.percentile(np.abs(out),98)+1e-8)*.4);out-=out.mean(axis=0)
    out*=0.16/max(np.max(np.abs(out)),1e-8)
    pcm=np.round(out*32767).astype('<i2')
    target=ROOT/'assets/audio/colony_ambience.wav'
    with wave.open(str(target),'wb') as f:
        f.setparams((2,2,sr,0,'NONE','not compressed'));f.writeframes(pcm.tobytes())
    result={'source':row,'seconds':24,'sample_rate':sr,'channels':2,'peak_dbfs':float(20*np.log10(np.max(np.abs(out)))), 'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(out*out)))), 'seam_step':int(np.max(np.abs(pcm[0].astype(int)-pcm[-1].astype(int)))), 'dc':out.mean(axis=0).tolist(),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'seed':195}
    assert result['seam_step']<400 and result['peak_dbfs']<-15 and np.max(np.abs(out.mean(axis=0)))<1e-8
    (ROOT/'.godot/card195/audio.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
