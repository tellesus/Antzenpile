"""Deterministic code-authored local nest relief; no remote landscape or state."""
from pathlib import Path
import math, random
r=random.Random(192)
pieces=['<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="440" viewBox="0 0 1600 440"><defs>']
for i in range(12):
    c=38+i*8
    pieces.append(f'<radialGradient id="p{i}" cx="32%" cy="22%" r="78%"><stop stop-color="rgb({c+36},{int(c*.76)+27},{int(c*.44)+15})"/><stop offset=".48" stop-color="rgb({c},{int(c*.67)},{int(c*.37)})"/><stop offset="1" stop-color="#14120e"/></radialGradient>')
pieces.extend(['<radialGradient id="soil"><stop stop-color="#705031"/><stop offset=".45" stop-color="#36291b"/><stop offset=".8" stop-color="#11130f"/><stop offset="1" stop-color="#050706" stop-opacity="0"/></radialGradient>', '<radialGradient id="mouth"><stop stop-color="#000"/><stop offset=".68" stop-color="#020302"/><stop offset="1" stop-color="#211a10"/></radialGradient></defs>', '<ellipse cx="800" cy="264" rx="740" ry="174" fill="url(#soil)"/>'])
# Ground spills fan away from the raised entrance. No horizon-length flat strip.
for i in range(1600):
    a=r.random()*math.tau; d=r.random()**.55
    x=800+math.cos(a)*d*700; y=254+math.sin(a)*d*142
    s=r.uniform(1.2,4.7)*(1-.45*d)
    opacity=(1-d)**.45*.75
    pieces.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{s:.1f}" ry="{s*.6:.1f}" fill="url(#p{r.randrange(7)})" opacity="{opacity:.2f}"/>')
# Rear-to-front sorted deposited pellets make a low volcanic cone, not a ring of light.
pellets=[]
for i in range(3900):
    a=r.random()*math.tau; d=.23+r.random()**.62*.77
    height=82*math.exp(-((d-.28)/.40)**2)
    x=800+math.cos(a)*d*370
    y=268+math.sin(a)*d*116-height
    s=r.uniform(2.3,6.5)*(1.1-.3*d)
    light=max(0,min(11,int(7+3*math.sin(a)-2*d+r.uniform(-2,2))))
    pellets.append((y,f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{s:.1f}" ry="{s*.75:.1f}" transform="rotate({r.uniform(-35,35):.0f} {x:.1f} {y:.1f})" fill="url(#p{light})"/>'))
pieces.extend(p for _,p in sorted(pellets))
# Mouth is recessed behind a ragged front lip, with a dark descending throat.
pieces.append('<path d="M710 202 C718 177 761 163 804 167 C847 164 883 181 892 203 C884 220 850 229 802 226 C754 231 720 219 710 202Z" fill="#271b10"/>')
pieces.append('<path d="M721 201 C729 180 767 173 803 176 C842 171 874 188 881 203 C868 219 838 219 802 219 C766 223 733 216 721 201Z" fill="url(#mouth)"/>')
for i in range(140):
    a=r.random()*math.tau
    x=801+math.cos(a)*r.uniform(87,98);y=200+math.sin(a)*r.uniform(27,33)
    s=r.uniform(2,4)
    pieces.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{s:.1f}" ry="{s*.7:.1f}" fill="url(#p{r.randrange(4,10)})"/>')
# Sparse plant fibers caught in excavated dirt, and curved traffic grooves.
for i in range(19):
    a=r.uniform(.15,math.pi-.15)
    x=800+math.cos(a)*130; y=219+math.sin(a)*25
    ex=800+math.cos(a)*r.uniform(280,480);ey=280+math.sin(a)*r.uniform(65,110)
    pieces.append(f'<path d="M{x:.1f} {y:.1f} Q{(x+ex)/2+18:.1f} {ey-5:.1f} {ex:.1f} {ey:.1f}" fill="none" stroke="#0c0d09" stroke-width="{r.uniform(1,3):.1f}" opacity=".48"/>')
for i in range(30):
    x=r.uniform(340,1260); y=r.uniform(265,355);dx=r.uniform(8,36)
    pieces.append(f'<path d="M{x:.1f} {y:.1f} q{dx/2:.1f} -7 {dx:.1f} -3" fill="none" stroke="#8f7950" stroke-width=".8" opacity=".3"/>')
pieces.append('</svg>')
Path('assets/graphics/colony/material/excavated_home.svg').write_text('\n'.join(pieces))
