"""Reuse197's file gates; additionally verify the rejected event pattern is absent."""
from pathlib import Path
import sys
import json
import numpy as np

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/music/pilot197'))
import check_pilot

check_pilot.OUT=ROOT/'builds/music_pilot198'
check_pilot.main()
for folder in sorted(check_pilot.OUT.glob('C[12]_*')):
    score=json.loads((folder/'score.json').read_text())
    events=score['events']
    assert not any(e['voice']=='string' for e in events)
    times=sorted(e['at'] for e in events if e['role']=='foreground')
    assert min(np.diff(times))>.75
    assert not any(40<=e['at']<60 for e in events if e['role']=='rhythm')
    print(folder.name,'no plucks/grouped foreground attacks; phrase spacing and breath PASS')
