"""Three original listening sketches, not a runtime soundtrack or the old score.

Existing Python/NumPy/SciPy only. All musical notes/phrases are authored below.
New CC0 piano multisamples, physical-string/additive and FM voices, linear room.
"""
from pathlib import Path
from functools import lru_cache
import hashlib
import json
import wave
import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
OUT=ROOT/'builds/music_pilot197'
RATE=44100
TARGET_LUFS=-23.5
ROLES=('foreground','space','bass','rhythm')


def db(value): return float(20*np.log10(max(float(value),1e-12)))
def hz(note): return 440*2**((note-69)/12)


def lowpass(x,cutoff):
    return signal.sosfilt(signal.butter(2,cutoff,fs=RATE,output='sos'),x,axis=0)


def highpass(x,cutoff):
    return signal.sosfilt(signal.butter(2,cutoff,'highpass',fs=RATE,output='sos'),x,axis=0)


def env(n,attack,release):
    y=np.ones(n)
    a=min(n,round(attack*RATE)); r=min(n,round(release*RATE))
    if a: y[:a]*=np.sin(np.linspace(0,np.pi/2,a))**2
    if r: y[-r:]*=np.cos(np.linspace(0,np.pi/2,r))**2
    return y


@lru_cache(maxsize=8)
def piano_source(midi):
    rate,data=wavfile.read(ROOT/f'.godot/card197/sources/piano_{midi}.wav')
    if data.dtype==np.int32: y=data.astype(np.float64)/2147483648
    elif data.dtype==np.int16: y=data.astype(np.float64)/32768
    else: raise ValueError('Unsupported piano encoding')
    if y.ndim==1: y=np.column_stack([y,y])
    y-=y.mean(axis=0)
    onset=np.flatnonzero(np.max(abs(y),axis=1)>np.max(abs(y))*0.008)[0]
    y=y[max(0,onset-round(rate*.006)):]
    if rate!=RATE: y=signal.resample_poly(y,RATE,rate,axis=0)
    # Preserve soft sample dynamics; one shared source gain, never per-note peak normalization.
    return y


def piano(note,seconds,velocity):
    roots=[48,52,56,60,64,68,72,75]
    root=min(roots,key=lambda x:abs(x-note)); src=piano_source(root)
    ratio=2**((note-root)/12)
    n=min(round(seconds*RATE),int((len(src)-1)/ratio))
    positions=np.arange(n)*ratio
    y=np.column_stack([np.interp(positions,np.arange(len(src)),src[:,c]) for c in range(2)])
    return lowpass(highpass(y,75),3700)*env(n,.014,.65)[:,None]*velocity


def string_voice(note,seconds,velocity,seed):
    # Damped stiff-string partials: higher modes decay faster; changing pick position avoids identical attacks.
    rng=np.random.default_rng(seed); t=np.arange(round(seconds*RATE))/RATE; f=hz(note)
    pick=rng.uniform(.19,.25); y=np.zeros(len(t))
    for partial in range(1,15):
        amp=np.sin(np.pi*partial*pick)/(partial**1.42)
        decay=np.exp(-t/(2.7/(1+.24*partial)))
        frequency=f*partial*np.sqrt(1+.000014*partial**2)
        y+=amp*decay*np.sin(2*np.pi*frequency*t+.13*partial)
    y=lowpass(y,3300)*env(len(t),.012,.7)*velocity*.34
    # Quiet, detuned secondary string for width; not a sampled or claimed real guitar.
    right=signal.resample_poly(y,10001,10000)[:len(y)]
    if len(right)<len(y): right=np.pad(right,(0,len(y)-len(right)))
    return np.column_stack([y,right])


def keys(note,seconds,velocity):
    t=np.arange(round(seconds*RATE))/RATE; f=hz(note)
    body=np.sin(2*np.pi*f*t+.85*np.exp(-t*2.3)*np.sin(2*np.pi*f*2*t))
    body+=.13*np.sin(2*np.pi*f*3*t)*np.exp(-t*3)
    body*=np.exp(-t*.68)*env(len(t),.018,.8)*velocity*.17
    # Gentle stereo tremolo; little high-frequency tine energy.
    return np.column_stack([body*(.95+.05*np.sin(2*np.pi*1.2*t)),body*(.95+.05*np.sin(2*np.pi*1.2*t+.5))])


def pad(note,seconds,velocity,phase):
    t=np.arange(round(seconds*RATE))/RATE; f=hz(note); sides=[]
    for ch in range(2):
        x=np.zeros(len(t))
        for partial,amp in [(1,.65),(2,.19),(3,.07),(4,.025)]:
            wander=.0011*np.sin(2*np.pi*.075*t+phase+ch*.8)
            angle=2*np.pi*np.cumsum(f*partial*(1+wander+(ch*2-1)*.0005))/RATE
            x+=amp*np.sin(angle+partial*.3)
        x*=env(len(t),1.7,2.5)*(.9+.1*np.sin(2*np.pi*.11*t+phase))*velocity*.12
        sides.append(x)
    return highpass(lowpass(np.column_stack(sides),1800),140)


def bass(note,seconds,velocity):
    t=np.arange(round(seconds*RATE))/RATE; f=hz(note)
    y=(np.sin(2*np.pi*f*t)+.17*np.sin(2*np.pi*2*f*t))*np.exp(-t*.55)
    y*=env(len(t),.045,.7)*velocity*.16
    return np.column_stack([y,y])


def drum(kind,velocity,seed):
    rng=np.random.default_rng(seed)
    if kind=='kick':
        t=np.arange(round(.42*RATE))/RATE
        y=np.sin(2*np.pi*np.cumsum(48+47*np.exp(-t*32))/RATE)*np.exp(-t*11)
        y=lowpass(y,240)*env(len(t),.008,.1)*velocity*.16
    elif kind=='rim':
        t=np.arange(round(.17*RATE))/RATE
        y=(np.sin(2*np.pi*191*t)+.4*np.sin(2*np.pi*416*t))*np.exp(-t*40)
        y+=lowpass(rng.normal(0,.12,len(t)),2400)*np.exp(-t*45)
        y=lowpass(y,2200)*env(len(t),.006,.05)*velocity*.055
    else:
        t=np.arange(round(.09*RATE))/RATE
        y=highpass(lowpass(rng.normal(0,1,len(t)),4200),1500)*np.exp(-t*65)
        y*=env(len(t),.005,.025)*velocity*.017
    return np.column_stack([y,y])


def add(track,sound,at,pan=0):
    start=round(at*RATE)
    if start<0: raise ValueError('negative note time')
    n=min(len(sound),len(track)-start)
    if n<=0: return
    p=np.array([np.cos((pan+1)*np.pi/4),np.sin((pan+1)*np.pi/4)])*np.sqrt(2)
    track[start:start+n]+=sound[:n]*p


def room(track,wet,seed):
    # A dense, damped stereo decay and asymmetric early reflections; linear so stems reconstruct.
    rng=np.random.default_rng(seed); seconds=3.8
    t=np.arange(round(seconds*RATE))/RATE
    ir=rng.normal(0,1,(len(t),2))*np.exp(-t[:,None]*6.908/3.2)
    ir*=np.minimum(t/.09,1)[:,None]
    ir=highpass(lowpass(ir,4100),230)
    ir/=np.sqrt(np.sum(ir**2,axis=0))[None,:]
    late=np.column_stack([signal.fftconvolve(track[:,0],ir[:,0])[:len(track)],signal.fftconvolve(track[:,1],ir[:,1])[:len(track)]])
    result=track+late*wet*.5
    for delay,gain in [(.047,.12),(.079,.07),(.131,.035)]:
        n=round(delay*RATE); result[n:]+=track[:-n,::-1]*gain*wet
    return result


def loudness(track):
    # ITU-R BS.1770 K weighting at the specified48kHz; resample analysis only.
    x=signal.resample_poly(track,160,147,axis=0)
    x=signal.lfilter([1.53512485958697,-2.69169618940638,1.19839281085285],[1,-1.69065929318241,.73248077421585],x,axis=0)
    x=signal.lfilter([1,-2,1],[1,-1.99004745483398,.99007225036621],x,axis=0)
    e=np.sum(x*x,axis=1); window=19200; hop=4800
    cs=np.r_[0,np.cumsum(e)]
    starts=np.arange(0,len(e)-window+1,hop)
    blocks=(cs[starts+window]-cs[starts])/window
    levels=-.691+10*np.log10(np.maximum(blocks,1e-20))
    absolute=blocks[levels>-70]
    if not len(absolute): return -120.
    relative=-.691+10*np.log10(absolute.mean())-10
    accepted=blocks[(levels>-70)&(levels>relative)]
    return float(-.691+10*np.log10(accepted.mean()))


def write(path,track):
    path.parent.mkdir(parents=True,exist_ok=True)
    assert np.isfinite(track).all() and np.max(abs(track))<.999
    with wave.open(str(path),'wb') as f:
        f.setnchannels(2); f.setsampwidth(2); f.setframerate(RATE)
        f.writeframes(np.rint(track*32767).astype('<i2').tobytes())


# Every two-bar room is deliberately voiced; no note randomizer composes the piece.
CONFIGS=[
 {'id':'A_Mosslight','bpm':68,'bars':20,'style':'spacious organic ambient','seed':19701,
  'chords':[(40,[55,59,64,66]),(48,[55,59,62,64]),(43,[54,59,62,67]),(38,[57,62,64,69]),(40,[55,59,64,66]),
            (48,[55,59,62,67]),(45,[55,59,64,69]),(38,[54,57,62,64]),(48,[55,59,62,64]),(40,[55,59,64,66])],
  'melody':[(1,1.5,71,2.8),(2,2.6,67,3.2),(4,1.2,66,2.8),(5,2.4,64,3.4),(7,1.1,62,4.0),
            (10,1.4,67,3.0),(11,2.5,71,2.8),(12,1.2,74,3.6),(14,2.2,69,3.5),(16,1.5,67,2.8),(17,2.7,64,4.0)]},
 {'id':'B_SlowCurrent','bpm':74,'bars':24,'style':'warm keys and restrained lofi','seed':19702,
  'chords':[(38,[54,57,61,64]),(47,[54,57,61,66]),(43,[54,57,59,62]),(45,[55,59,62,64])]*3,
  'melody':[(2,1.5,69,1.8),(2,3.0,66,2.2),(4,2.5,64,2.6),(6,1.5,66,1.8),(7,2.5,61,3.0),
            (10,1.5,69,1.8),(11,2.5,73,2.4),(13,1.5,71,2.6),(14,2.7,66,2.5),(18,2.0,64,3.0),(20,2.5,61,3.5)]},
 {'id':'C_RootAndSky','bpm':72,'bars':24,'style':'organic electronic hybrid with a long breath','seed':19703,
  'chords':[(45,[52,59,61,64]),(42,[52,57,61,64]),(38,[54,57,61,64]),(40,[56,59,61,66]),
            (45,[52,59,61,64]),(42,[52,57,61,66]),(38,[54,57,61,64]),(40,[56,59,64,66]),
            (38,[54,57,61,64]),(45,[52,57,59,64]),(40,[56,59,61,64]),(45,[52,57,59,61])],
  'melody':[(1,2.0,69,2.6),(3,1.5,71,2.8),(4,2.4,73,2.6),(6,1.2,68,3.0),(7,2.7,64,3.5),
            (10,1.5,66,2.6),(11,2.8,64,3.2),(18,1.0,68,2.6),(19,2.5,71,2.8),(21,1.5,69,3.5)]}
]


def render(config):
    name=config['id']; bpm=config['bpm']; beat=60/bpm; bar=4*beat; n=round((bar*config['bars']+6)*RATE)
    tracks={k:np.zeros((n,2)) for k in ROLES}; rng=np.random.default_rng(config['seed']); events=[]
    def note(role,voice,midi,at,duration,velocity,pan=0):
        seed=int(rng.integers(2**30))
        sound={'piano':lambda:piano(midi,duration,velocity),'string':lambda:string_voice(midi,duration,velocity,seed),
               'keys':lambda:keys(midi,duration,velocity),'pad':lambda:pad(midi,duration,velocity,seed%20),
               'bass':lambda:bass(midi,duration,velocity)}[voice]()
        add(tracks[role],sound,at,pan)
        events.append({'role':role,'voice':voice,'midi':midi,'at':round(at,5),'seconds':duration,'velocity':velocity,'pan':pan,'seed':seed})
    for i,(root,chord) in enumerate(config['chords']):
        b=i*2; at=b*bar
        breath=(name.startswith('A') and b in [8,18]) or (name.startswith('B') and b in [0,16]) or (name.startswith('C') and b in [12,14,16])
        for j,midi in enumerate(chord):
            note('space','pad',midi,at+.2,bar*2+3,.23 if name.startswith('B') else .3,[-.4,.25,-.15,.4][j])
        if not breath:
            if name.startswith('A'):
                for j,midi in enumerate(chord[:3]): note('foreground','string',midi,at+.35+j*.12,5.2,.4-j*.035,[-.27,.1,.29][j])
                note('foreground','piano',chord[0],at+bar+beat*.7,4.4,.3,-.12)
            elif name.startswith('B'):
                for offset,vel in [(beat*.12,.5),(bar+beat*1.6,.36)]:
                    for j,midi in enumerate(chord): note('foreground','keys',midi,at+offset+j*.018,3.8,vel,[-.3,-.1,.15,.3][j])
                if b in [4,10,20]: note('foreground','piano',chord[-1],at+beat*2.6,3.8,.35,.1)
            else:
                for j,midi in enumerate(chord[:3]): note('foreground','string',midi,at+.4+j*.105,5.8,.35,[-.3,0,.3][j])
                if b in [4,8,18,20]:
                    for j,midi in enumerate(chord): note('foreground','keys',midi,at+bar+beat*.6+j*.02,4,.24,[-.2,-.1,.1,.2][j])
            note('bass','bass',root-12 if root>=42 else root,at+beat*.15,bar*1.8,.38)
            if name.startswith('B') and b>=2: note('bass','bass',root,at+bar+beat*1.7,beat*1.4,.19)
    for b,offset,midi,duration in config['melody']:
        voice='piano' if name.startswith(('A','C')) else 'keys'
        note('foreground',voice,midi,b*bar+offset*beat,duration,.43 if voice=='piano' else .62,.1)
    for b in range(config['bars']):
        active=(name.startswith('B') and 2<=b<22 and not 16<=b<18) or (name.startswith('C') and 4<=b<22 and not 12<=b<18)
        if not active: continue
        pattern=[('kick',.03,.42),('rim',1.07,.6),('kick',2.55,.25),('rim',3.07,.45)]
        if name.startswith('B') and b%2==0: pattern += [('hat',.66,.35),('hat',2.67,.28)]
        for kind,offset,vel in pattern:
            if name.startswith('C') and kind=='kick' and offset>2: continue
            at=(b*4+offset)*beat
            seed=int(rng.integers(2**30)); add(tracks['rhythm'],drum(kind,vel,seed),at,.1 if kind=='rim' else 0)
            events.append({'role':'rhythm','voice':kind,'at':round(at,5),'velocity':vel,'seed':seed})
    for i,role in enumerate(ROLES):
        tracks[role]=room(tracks[role],{'foreground':.32,'space':.48,'bass':.035,'rhythm':.1}[role],config['seed']+i)
        tracks[role]-=tracks[role].mean(axis=0)
        tracks[role]*=env(n,1.2,4.0)[:,None]
    mix=sum(tracks.values()); before=loudness(mix); gain=10**((TARGET_LUFS-before)/20)
    tracks={k:v*gain for k,v in tracks.items()}; mix=sum(tracks.values())
    true_peak=np.max(abs(signal.resample_poly(mix,4,1,axis=0)))
    if db(true_peak)>-5: raise ValueError(f'{name}: excessive crest {db(true_peak):.2f}dBTP; change arrangement, not stem normalization')
    folder=OUT/name
    write(folder/'preview.wav',mix)
    for role,track in tracks.items(): write(folder/f'{role}.wav',track)
    gap=np.zeros((round(2.5*RATE),2)); repeated=np.concatenate([mix,gap,mix,gap,mix])
    write(folder/'repeat_3_passes.wav',repeated)
    (folder/'score.json').write_text(json.dumps({'config':config,'events':events,'sample_rate':RATE,'role_gains':'one shared gain','master_gain':gain},indent=2)+'\n')
    row={'id':name,'style':config['style'],'bpm':bpm,'seconds':len(mix)/RATE,'repeat_seconds':len(repeated)/RATE,
         'integrated_lufs':loudness(mix),'sample_peak_dbfs':db(np.max(abs(mix))),'oversampled_peak_dbtp_estimate':db(true_peak),
         'dc':mix.mean(axis=0).tolist(),'frames':len(mix),'events':len(events),'master_gain':gain,
         'repeat_gap_seconds':2.5,'preview_sha256':hashlib.sha256((folder/'preview.wav').read_bytes()).hexdigest(),
         'stem_reconstruction_max_error':float(np.max(abs(sum(tracks.values())-mix))),'role_rms':{k:float(np.sqrt(np.mean(v*v))) for k,v in tracks.items()}}
    print(json.dumps(row),flush=True)
    return row


def main():
    manifest=json.loads((HERE/'sources.json').read_text())
    for row in manifest['samples']:
        assert hashlib.sha256((ROOT/'.godot/card197/sources'/row['file']).read_bytes()).hexdigest()==row['sha256']
    t=np.arange(3*RATE)/RATE; calibration=np.column_stack([.1*np.sin(2*np.pi*1000*t)]*2)
    reading=loudness(calibration); assert abs(reading+20)<.15,reading
    OUT.mkdir(parents=True,exist_ok=True)
    rows=[render(c) for c in CONFIGS]
    report={'scope':'offline original listening sketches; no runtime integration or human listening acceptance','rate':RATE,'pcm_bits':16,'channels':2,
            'loudness':'original BS.1770 stereo K-weighted gated implementation; analysis resampled to48k; not a certified meter',
            'target_lufs':TARGET_LUFS,'calibration_stereo_1khz_0_1_peak_lufs':reading,'sketches':rows,'paid_services':0,'new_optional_tools':0}
    (OUT/'metrics.json').write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__': main()
