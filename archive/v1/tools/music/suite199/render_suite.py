"""C2 production suite: original synth voices only; no piano/source recordings.

Four phase-compatible16-bar sections, four roles, circular voice/room tails and
one listening demo. This is production audio, not runtime integration.
"""
from pathlib import Path
import sys
import json
import hashlib
import itertools
import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/music/pilot197'))
import render_pilot as audio
sys.path.insert(0,str(ROOT/'tools/music/pilot198'))
from render_revision import soft_keys

OUT=ROOT/'builds/music_suite199'
RATE=44100
BPM=72
BEAT=60/BPM
BAR=4*BEAT
FRAMES=16*147000
ROLES=('foreground','space','bass','rhythm')
CHORDS=audio.CONFIGS[2]['chords'][:8]
TARGET_LUFS=-23.5
SECTION_SPECS=[
    {'id':'Air','space':.25,'bass':.17,'keys':.42,'rhythm':0,
     'melody':[(5,2,64,3.4),(9,1.5,61,3.8),(13,2.5,59,3.6)]},
    {'id':'Warm','space':.26,'bass':.29,'keys':.63,'rhythm':0,
     'melody':[(1,2,64,3.4),(3,1.5,61,3.8),(6,1.2,59,3.2),(7,2.7,61,3.6),
               (10,1.5,64,3.6),(11,2.8,66,3.8),(14,1,64,3.5)]},
    {'id':'Current','space':.26,'bass':.32,'keys':.63,'rhythm':1,
     'melody':[(1,2,64,3.4),(3,1.5,61,3.8),(6,1.2,59,3.2),(7,2.7,61,3.6),
               (10,1.5,64,3.6),(11,2.8,66,3.8),(14,1,64,3.5)]},
    {'id':'Breath','space':.16,'bass':0,'keys':0,'rhythm':0,'melody':[]}
]


def add_periodic(track,sound,at,pan=0):
    start=round(at*RATE)%len(track)
    gain=np.array([np.cos((pan+1)*np.pi/4),np.sin((pan+1)*np.pi/4)])*np.sqrt(2)
    sound=sound*gain
    offset=0
    while offset<len(sound):
        count=min(len(sound)-offset,len(track)-start)
        track[start:start+count]+=sound[offset:offset+count]
        offset+=count; start=0


def circular_room(track,wet,seed):
    # Same damped room character as C2, with periodic convolution for loop tails.
    rng=np.random.default_rng(seed)
    t=np.arange(round(3.8*RATE))/RATE
    ir=rng.normal(0,1,(len(t),2))*np.exp(-t[:,None]*6.908/3.2)
    ir*=np.minimum(t/.09,1)[:,None]
    ir=audio.highpass(audio.lowpass(ir,4100),230)
    ir/=np.sqrt(np.sum(ir**2,axis=0))[None,:]
    late=np.fft.irfft(np.fft.rfft(track,axis=0)*np.fft.rfft(ir,n=len(track),axis=0),n=len(track),axis=0)
    result=track+late*wet*.5
    for delay,gain in [(.047,.12),(.079,.07),(.131,.035)]:
        result+=np.roll(track[:,::-1],round(delay*RATE),axis=0)*gain*wet
    return result


def build_section(spec):
    tracks={role:np.zeros((FRAMES,2)) for role in ROLES}; events=[]
    def add(role,voice,note,at,duration,velocity,pan=0,phase=0):
        if voice=='c2_keys': sound=soft_keys(note,duration,velocity)
        elif voice=='pad': sound=audio.pad(note,duration,velocity,phase)
        elif voice=='bass': sound=audio.bass(note,duration,velocity)
        else: raise ValueError(voice)
        add_periodic(tracks[role],sound,at,pan)
        events.append({'role':role,'voice':voice,'note':note,'at':at,'seconds':duration,'velocity':velocity,'pan':pan,'phase':phase})
    for i,(root,chord) in enumerate(CHORDS):
        at=i*2*BAR
        for j,note in enumerate(chord):
            add('space','pad',note,at+.2,2*BAR+3,spec['space'],[-.4,.25,-.15,.4][j],(19703+i*4+j)%20)
        if spec['bass']:
            add('bass','bass',root-12 if root>=42 else root,at+BEAT*.15,BAR*1.8,spec['bass'])
    for b,offset,note,duration in spec['melody']:
        add('foreground','c2_keys',note,b*BAR+offset*BEAT,duration,spec['keys'],.08)
    if spec['rhythm']:
        for b in range(4,14):
            for k,(kind,offset,velocity) in enumerate([('kick',.03,.33),('rim',3.07,.32)]):
                at=(b*4+offset)*BEAT
                add_periodic(tracks['rhythm'],audio.drum(kind,velocity,19802+b*4+k),at,.08 if kind=='rim' else 0)
                events.append({'role':'rhythm','voice':kind,'at':at,'velocity':velocity,'seed':19802+b*4+k})
    for i,role in enumerate(ROLES):
        tracks[role]=circular_room(tracks[role],{'foreground':.38,'space':.45,'bass':.035,'rhythm':.1}[role],19703+i)
        tracks[role]-=tracks[role].mean(axis=0)
    if spec['id']=='Breath':
        # A full four-bar rest, with a two-bar fade on either side of the periodic bed.
        mask=np.ones(FRAMES)
        length=round(2*BAR*RATE)
        mask[:length]=np.sin(np.linspace(0,np.pi/2,length))**2
        start=round(10*BAR*RATE)
        mask[start:start+length]=np.cos(np.linspace(0,np.pi/2,length))**2
        mask[start+length:]=0
        for role in ROLES: tracks[role]*=mask[:,None]
    return tracks,events


def peak(track): return audio.db(np.max(abs(signal.resample_poly(track,4,1,axis=0))))


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    sections={}; events={}
    for spec in SECTION_SPECS:
        sections[spec['id']],events[spec['id']]=build_section(spec)
    gain=10**((TARGET_LUFS-audio.loudness(sum(sections['Current'].values())))/20)
    for tracks in sections.values():
        for role in ROLES: tracks[role]*=gain
    rows=[]
    for name,tracks in sections.items():
        folder=OUT/'sections'/name; mix=sum(tracks.values())
        combinations=[]
        for mask in range(1,16):
            selected=[tracks[role] for i,role in enumerate(ROLES) if mask&(1<<i)]
            subset=sum(selected)
            combinations.append({'mask':mask,'sample_peak_dbfs':audio.db(np.max(abs(subset)))})
        for role,track in tracks.items(): audio.write(folder/f'{role}.wav',track)
        audio.write(folder/'full.wav',mix)
        wrap_limits={}
        for role,track in tracks.items():
            nearby=np.concatenate([np.diff(track[-4410:],axis=0),np.diff(track[:4410],axis=0)])
            local_limit=float(np.quantile(abs(nearby),.99))*1.25+.00005
            wrap_limits[role]=local_limit
        foreground=sorted(e['at'] for e in events[name] if e['role']=='foreground')
        assert not foreground or min(np.diff(foreground))>.75
        assert not any(e['voice'] in ['piano','soft_piano','string'] for e in events[name])
        row={'id':name,'frames':FRAMES,'seconds':FRAMES/RATE,'lufs':audio.loudness(mix),'peak_dbtp_estimate':peak(mix),
             'roles':{role:{'rms':float(np.sqrt(np.mean(track*track))),
                    'wrap_step':float(np.max(abs(track[0]-track[-1]))),
                    'nearby_slope_limit':wrap_limits[role],
                    'sha256':hashlib.sha256((folder/f'{role}.wav').read_bytes()).hexdigest()} for role,track in tracks.items()},
             'combinations':combinations,'events':len(events[name]),'foreground_events':len(foreground)}
        assert row['peak_dbtp_estimate']< -5
        # A periodic waveform need not have identical adjacent samples at its wrap.
        # Reject an outlier step, not the ordinary slope of a continuous tone.
        assert all(v['wrap_step']<=v['nearby_slope_limit'] and v['wrap_step']<.01 for v in row['roles'].values())
        assert max(c['sample_peak_dbfs'] for c in combinations)< -5
        rows.append(row); print(json.dumps({k:v for k,v in row.items() if k not in ['roles','combinations']}),flush=True)
    # One deterministic example of adaptive presentation, not a simulation-driven scheduler.
    sequence=['Air','Warm','Current','Breath','Warm']
    demo_roles={role:np.zeros((len(sequence)*FRAMES,2)) for role in ROLES}
    fade_frames=round(2*BAR*RATE)
    fade=np.sin(np.linspace(0,np.pi/2,fade_frames))**2
    cue_points=[]
    for i,name in enumerate(sequence):
        start=i*FRAMES
        for role in ROLES:
            current=sections[name][role].copy()
            if i:
                previous=sections[sequence[i-1]][role]
                current[:fade_frames]=previous[:fade_frames]*(1-fade[:,None])+current[:fade_frames]*fade[:,None]
            demo_roles[role][start:start+FRAMES]=current
        cue_points.append({'at':start/RATE,'section':name,'fade_seconds':0 if not i else fade_frames/RATE})
    for role in ROLES:
        demo_roles[role]*=audio.env(len(demo_roles[role]),1.4,5)[:,None]
    demo=sum(demo_roles.values())
    for role,track in demo_roles.items(): audio.write(OUT/'demo_parts'/f'{role}.wav',track)
    audio.write(OUT/'WarmCurrent_Layered.wav',demo)
    # Technical cue overlap only; never mixed into the main listening preview.
    cue_mix=demo.copy(); cue_events=[]
    for name,at in [('returned_discovery',83),('returned_alarm',139),('returned_discovery',228)]:
        rate,pcm=wavfile.read(ROOT/'assets/audio'/f'{name}.wav')
        assert rate==RATE and pcm.dtype==np.int16
        sound=pcm.astype(float)/32768*10**(-15/20)
        if sound.ndim==1: sound=np.column_stack([sound,sound])
        audio.add(cue_mix,sound,at)
        cue_events.append({'cue':name,'at':at,'gain_db':-15})
    audio.write(OUT/'Technical_CueOverlap.wav',cue_mix)
    assert peak(cue_mix)< -3 and peak(demo)< -5
    score={'bpm':BPM,'bars_per_section':16,'frames_per_section':FRAMES,'chords':CHORDS,'roles':ROLES,
           'specs':SECTION_SPECS,'events':events,'shared_gain':gain,'demo_sequence':cue_points,
           'fade_curve':'complementary sin-squared / cos-squared; weights sum to1',
           'technical_cue_events':cue_events,'source_audio':'original synthesis; no sampled piano, plucks or reference recording'}
    (OUT/'score.json').write_text(json.dumps(score,indent=2)+'\n')
    metrics={'scope':'C2-based offline production suite, not integrated gameplay; listening/fatigue pending',
             'rate':RATE,'pcm_bits':16,'channels':2,'bpm':BPM,'frames_per_section':FRAMES,'sections':rows,
             'shared_gain':gain,'demo_seconds':len(demo)/RATE,'demo_lufs':audio.loudness(demo),
             'demo_peak_dbtp_estimate':peak(demo),'cue_overlap_peak_dbtp_estimate':peak(cue_mix),
             'whole_mix_rest_interval_seconds':[200,213.33333333333334],
             'fade_seconds':fade_frames/RATE,'transition_weights_sum_error':float(np.max(abs(fade+(1-fade)-1)))}
    (OUT/'metrics.json').write_text(json.dumps(metrics,indent=2)+'\n')
    print('DEMO',metrics['demo_seconds'],metrics['demo_lufs'],metrics['demo_peak_dbtp_estimate'],flush=True)


if __name__=='__main__': main()
