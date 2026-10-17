"""C-based listening revisions: remove repeated chord attacks; keep197 recoverable."""
from pathlib import Path
import sys
import hashlib
import json
import numpy as np
from scipy import signal

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/music/pilot197'))
import render_pilot as audio

OUT=ROOT/'builds/music_pilot198'
RATE=audio.RATE
ROLES=audio.ROLES
BASE=audio.CONFIGS[2]


def soft_keys(note,seconds,velocity):
    t=np.arange(round(seconds*RATE))/RATE
    f=audio.hz(note)
    # Softer attack and a slower, simpler tine envelope than197's struck key voice.
    y=np.sin(2*np.pi*f*t+.3*np.exp(-t*.8)*np.sin(2*np.pi*f*2*t))
    y+=.055*np.sin(2*np.pi*f*3*t)*np.exp(-t*1.2)
    y*=np.exp(-t*.3)*audio.env(len(t),.16,.9)*velocity*.15
    stereo=np.column_stack([y*(.97+.03*np.sin(2*np.pi*.8*t)),y*(.97+.03*np.sin(2*np.pi*.8*t+.4))])
    return audio.lowpass(stereo,2500)


def render(warm):
    name='C2_WarmCurrent' if warm else 'C1_QuietSky'
    seed=19802 if warm else 19801
    beat=60/72; bar=4*beat; n=round(86*RATE)
    tracks={k:np.zeros((n,2)) for k in ROLES}
    events=[]
    def add(role,voice,midi,at,duration,velocity,pan=0,phase=0):
        if voice=='pad': sound=audio.pad(midi,duration,velocity,phase)
        elif voice=='bass': sound=audio.bass(midi,duration,velocity)
        elif voice=='soft_piano':
            sound=audio.piano(midi,duration,velocity)
            sound=audio.lowpass(sound,2800)*audio.env(len(sound),.085,.8)[:,None]
            # The soft sampled voice was effectively masked by197's synthetic plucks.
            # Calibrate the whole instrument together, preserving relative sampled-note levels.
            sound*=96
        elif voice=='soft_keys': sound=soft_keys(midi,duration,velocity)
        else: raise ValueError(voice)
        audio.add(tracks[role],sound,at,pan)
        events.append({'role':role,'voice':voice,'midi':midi,'at':at,'seconds':duration,'velocity':velocity,'pan':pan,'phase':phase})
    for i,(root,chord) in enumerate(BASE['chords']):
        b=i*2; at=b*bar
        for j,midi in enumerate(chord):
            # C's harmonic structure remains; all chord tones swell together slowly.
            add('space','pad',midi,at+.2,bar*2+3,.26 if warm else .3,[-.4,.25,-.15,.4][j],(19703+i*4+j)%20)
        if b not in [12,14,16]:
            add('bass','bass',root-12 if root>=42 else root,at+beat*.15,bar*1.8,.32)
        # Deliberately no three-note pluck or rolled-key chord in either revision.
    melody=BASE['melody'] if not warm else [
        (1,2,64,3.4),(3,1.5,61,3.8),(6,1.2,59,3.2),(7,2.7,61,3.6),
        (10,1.5,64,3.6),(11,2.8,66,3.8),(18,1,64,3.5),(20,1.5,61,3.6),
        (21,2.5,59,3.4),(22,2.5,57,4.0)]
    for b,offset,midi,duration in melody:
        add('foreground','soft_keys' if warm else 'soft_piano',midi,b*bar+offset*beat,duration,.63 if warm else .48,.08)
    # Keep C's light rhythm and20-second breath, with fewer percussive events per bar.
    for b in range(4,22):
        if 12<=b<18: continue
        for k,(kind,offset,velocity) in enumerate([('kick',.03,.33),('rim',3.07,.32)]):
            at=(b*4+offset)*beat
            audio.add(tracks['rhythm'],audio.drum(kind,velocity,seed+b*4+k),at,.08 if kind=='rim' else 0)
            events.append({'role':'rhythm','voice':kind,'at':at,'velocity':velocity})
    for i,role in enumerate(ROLES):
        tracks[role]=audio.room(tracks[role],{'foreground':.38,'space':.45,'bass':.035,'rhythm':.1}[role],19703+i)
        tracks[role]-=tracks[role].mean(axis=0)
        tracks[role]*=audio.env(n,1.2,4)[:,None]
    mix=sum(tracks.values()); gain=10**((audio.TARGET_LUFS-audio.loudness(mix))/20)
    tracks={k:v*gain for k,v in tracks.items()}; mix=sum(tracks.values())
    peak=audio.db(np.max(abs(signal.resample_poly(mix,4,1,axis=0))))
    if peak>-5: raise ValueError(f'Change arrangement/headroom: {name} peak {peak}')
    folder=OUT/name
    audio.write(folder/'preview.wav',mix)
    for role,track in tracks.items(): audio.write(folder/f'{role}.wav',track)
    gap=np.zeros((round(2.5*RATE),2))
    audio.write(folder/'repeat_3_passes.wav',np.concatenate([mix,gap,mix,gap,mix]))
    foreground=sorted(e['at'] for e in events if e['role']=='foreground')
    assert min(np.diff(foreground))>.75
    assert not any(e['voice']=='string' for e in events)
    (folder/'score.json').write_text(json.dumps({'id':name,'bpm':72,'chords':BASE['chords'],'events':events,
        'master_gain':gain,'foreground_min_onset_gap_seconds':min(np.diff(foreground))},indent=2)+'\n')
    row={'id':name,'seconds':len(mix)/RATE,'frames':len(mix),'bpm':72,'integrated_lufs':audio.loudness(mix),
        'oversampled_peak_dbtp_estimate':peak,'repeat_seconds':263,'foreground_events':len(foreground),
        'foreground_min_onset_gap_seconds':min(np.diff(foreground)),'plucked_string_events':0,
        'grouped_foreground_chord_events':0,'master_gain':gain,
        'preview_sha256':hashlib.sha256((folder/'preview.wav').read_bytes()).hexdigest(),
        'role_rms':{k:float(np.sqrt(np.mean(v*v))) for k,v in tracks.items()}}
    print(json.dumps(row),flush=True)
    return row


def main():
    sources=json.loads((ROOT/'tools/music/pilot197/sources.json').read_text())
    for row in sources['samples']:
        assert hashlib.sha256((ROOT/'.godot/card197/sources'/row['file']).read_bytes()).hexdigest()==row['sha256']
    OUT.mkdir(parents=True,exist_ok=True)
    rows=[render(False),render(True)]
    (OUT/'metrics.json').write_text(json.dumps({'scope':'C-based standalone listening revisions; player acceptance pending',
        'target_lufs':audio.TARGET_LUFS,'rate':RATE,'channels':2,'pcm_bits':16,'sketches':rows},indent=2)+'\n')


if __name__=='__main__': main()
