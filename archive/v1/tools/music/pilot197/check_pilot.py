"""Independent file-level audition checks; does not establish musical enjoyment."""
from pathlib import Path
import json
import wave
import numpy as np
from scipy.io import wavfile
from scipy import signal
from render_pilot import loudness,db

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'builds/music_pilot197'


def pcm(path):
    with wave.open(str(path),'rb') as f:
        assert (f.getframerate(),f.getnchannels(),f.getsampwidth())==(44100,2,2),path
        return np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').reshape(-1,2).astype(float)/32768


def main():
    rows=[]
    metrics=json.loads((OUT/'metrics.json').read_text())
    for row in metrics['sketches']:
        folder=OUT/row['id']; mix=pcm(folder/'preview.wav')
        stems=[pcm(folder/f'{role}.wav') for role in ['foreground','space','bass','rhythm']]
        assert len(mix)==row['frames'] and np.isfinite(mix).all()
        assert 60<=len(mix)/44100<=90
        error=float(np.max(abs(sum(stems)-mix))); assert error<.0001,error
        measured=loudness(mix); assert abs(measured-metrics['target_lufs'])<.06,measured
        peak=db(np.max(abs(signal.resample_poly(mix,4,1,axis=0)))); assert peak< -5,peak
        assert np.max(abs(mix[:2]))<.0001 and np.max(abs(mix[-2:]))<.0001
        repeat=pcm(folder/'repeat_3_passes.wav'); gap=round(2.5*44100)
        assert len(repeat)==3*len(mix)+2*gap
        for i in range(3): assert np.array_equal(repeat[i*(len(mix)+gap):i*(len(mix)+gap)+len(mix)],mix)
        decoded=pcm(folder/'decoded_preview.wav')
        assert abs(len(decoded)-len(mix))<4410 and np.max(abs(decoded))<.9
        # Bundled MP3 encoding applies a consistent ~0.45dB attenuation.
        # Verify the small offset and, below, the actual delivered A/B/C loudness match.
        encoded_loudness=loudness(decoded); assert abs(encoded_loudness-measured)<.6
        assert np.sqrt(np.mean((mix[:,0]-mix[:,1])**2))>.0001
        rows.append({'id':row['id'],'seconds':len(mix)/44100,'lufs':measured,'decoded_mp3_lufs':encoded_loudness,
                     'peak_estimate_dbtp':peak,'pcm_stem_sum_max_error':error,'repeat_three_passes_exact':True})
    assert max(r['lufs'] for r in rows)-min(r['lufs'] for r in rows)<.1
    assert max(r['decoded_mp3_lufs'] for r in rows)-min(r['decoded_mp3_lufs'] for r in rows)<.1
    report={'passed':True,'scope':'PCM/encoding/reconstruction/loudness preparation only; player listening pending','sketches':rows}
    (OUT/'checks.json').write_text(json.dumps(report,indent=2)+'\n'); print(json.dumps(report,indent=2))


if __name__=='__main__': main()
