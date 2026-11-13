"""File-based production checks; not a listening or runtime integration gate."""
from pathlib import Path
import sys
import json
import itertools
import numpy as np

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/music/pilot197'))
from check_pilot import pcm
from render_pilot import loudness,db

OUT=ROOT/'builds/music_suite199'
ROLES=['foreground','space','bass','rhythm']


def main():
    metrics=json.loads((OUT/'metrics.json').read_text())
    score=json.loads((OUT/'score.json').read_text())
    n=metrics['frames_per_section']; rows=[]; max_reconstruction=0
    for spec in score['specs']:
        name=spec['id']; folder=OUT/'sections'/name
        tracks={role:pcm(folder/f'{role}.wav') for role in ROLES}
        mix=pcm(folder/'full.wav')
        assert all(len(t)==n and np.isfinite(t).all() for t in [mix,*tracks.values()])
        error=float(np.max(abs(sum(tracks.values())-mix))); max_reconstruction=max(max_reconstruction,error)
        assert error<.0001
        for role,track in tracks.items():
            nearby=np.concatenate([np.diff(track[-4410:],axis=0),np.diff(track[:4410],axis=0)])
            step=float(np.max(abs(track[0]-track[-1])))
            assert step<=float(np.quantile(abs(nearby),.99))*1.25+.0001 and step<.01
        for mask in range(1,16):
            subset=sum(t for i,t in enumerate(tracks.values()) if mask&(1<<i))
            assert db(np.max(abs(subset)))< -5
        times=sorted(e['at'] for e in score['events'][name] if e['role']=='foreground')
        assert not times or min(np.diff(times))>.75
        assert all(e['voice'] in ['pad','bass','c2_keys','kick','rim'] for e in score['events'][name])
        if name=='Breath': assert all(np.max(abs(tracks[role]))==0 for role in ['foreground','bass','rhythm'])
        rows.append({'id':name,'frames':len(mix),'lufs':loudness(mix),'reconstruction_max_error':error,
                     'source_roles_checked':4,'part_combinations_checked':15,'foreground_events':len(times)})
    demo=pcm(OUT/'WarmCurrent_Layered.wav')
    stems=[pcm(OUT/'demo_parts'/f'{role}.wav') for role in ROLES]
    assert len(demo)==5*n and max(abs(demo[0]))==0 and max(abs(demo[-1]))==0
    error=float(np.max(abs(sum(stems)-demo))); assert error<.0001
    assert db(np.max(abs(demo)))< -5
    # Adjacent samples at a crossfade boundary must not be outliers relative to nearby slopes.
    for index in range(1,5):
        at=index*n
        nearby=np.diff(demo[at-4410:at+4410],axis=0)
        assert np.max(abs(demo[at]-demo[at-1]))<np.quantile(abs(nearby),.999)*1.5+.0001
    decoded=pcm(OUT/'WarmCurrent_Layered_decoded.wav')
    assert len(decoded)==len(demo) and np.max(abs(decoded))<.9
    assert abs(loudness(decoded)-loudness(demo))<.6
    cues=pcm(OUT/'Technical_CueOverlap.wav')
    assert cues.shape==demo.shape and np.max(abs(cues-demo))>.001
    assert db(np.max(abs(cues)))< -3
    assert score['fade_curve'].startswith('complementary') and metrics['transition_weights_sum_error']<1e-12
    # Actual role tracks also leave foreground and percussion silent through the latter part of Breath.
    breath=slice(3*n+int(10*44100),4*n)
    assert np.max(abs(stems[0][breath]))==0 and np.max(abs(stems[3][breath]))==0
    whole_rest=slice(3*n+12*147000,4*n)
    assert np.max(abs(demo[whole_rest]))==0
    report={'passed':True,'scope':'offline file/loop/transition/cue-overlap preparation; listening and game integration pending',
            'section_frames':n,'section_seconds':n/44100,'sections':rows,'demo_seconds':len(demo)/44100,
            'demo_lufs':loudness(demo),'decoded_mp3_lufs':loudness(decoded),'demo_reconstruction_max_error':error,
            'part_combinations_checked':60,'piano_or_plucked_recordings':0,'silent_foreground_rhythm_breath_confirmed':True,
            'whole_mix_rest_seconds':len(demo[whole_rest])/44100}
    (OUT/'checks.json').write_text(json.dumps(report,indent=2)+'\n'); print(json.dumps(report,indent=2))


if __name__=='__main__': main()
