"""Original SVG masks and Nursery vignette; no external artwork or runtime noise."""
from pathlib import Path
import math
import random

out = Path(__file__).resolve().parents[2] / "assets/graphics/proof"
out.mkdir(parents=True, exist_ok=True)
rng = random.Random(88)
cloud = ['<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256"><defs><radialGradient id="mist"><stop stop-color="#fff" stop-opacity="0.64"/><stop offset="0.5" stop-color="#fff" stop-opacity="0.28"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient></defs>']
for i in range(18):
    angle = i*2.39996
    spread = 13 + math.sqrt(i/18)*60
    x,y = 128+math.cos(angle)*spread,128+math.sin(angle)*spread*0.72
    cloud.append(f'<ellipse cx="{x:.2f}" cy="{y:.2f}" rx="{rng.uniform(25,48):.2f}" ry="{rng.uniform(17,36):.2f}" fill="url(#mist)" opacity="0.42"/>')
cloud.append('</svg>')
(out/'scent_cloud.svg').write_text(''.join(cloud),encoding='utf-8')

water = '''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256"><defs><radialGradient id="surface"><stop stop-color="#fff" stop-opacity="0.22"/><stop offset="0.72" stop-color="#fff" stop-opacity="0.13"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient></defs><path d="M39 137 Q55 103 99 111 Q149 93 191 117 Q230 128 208 146 Q188 173 151 164 Q105 180 64 158 Z" fill="url(#surface)"/><g fill="none" stroke="#fff" stroke-linecap="round"><path d="M44 137 Q66 115 100 121 Q144 104 190 124" stroke-opacity="0.35" stroke-width="2"/><path d="M61 145 Q106 162 159 148 Q188 145 202 134" stroke-opacity="0.22" stroke-width="1.5"/><path d="M81 134 Q127 123 171 134" stroke-opacity="0.25" stroke-width="1"/></g></svg>'''
(out/'water_impression.svg').write_text(water,encoding='utf-8')

soil = ['<svg xmlns="http://www.w3.org/2000/svg" width="384" height="272" viewBox="0 0 384 272"><defs><radialGradient id="earth"><stop stop-color="#57412c"/><stop offset="0.62" stop-color="#34251b"/><stop offset="1" stop-color="#121218" stop-opacity="0"/></radialGradient><radialGradient id="cavity"><stop stop-color="#17181a"/><stop offset="0.74" stop-color="#26221c"/><stop offset="0.94" stop-color="#725332"/><stop offset="1" stop-color="#a6834e" stop-opacity="0.35"/></radialGradient><clipPath id="rim"><path d="M54 112 Q68 48 148 44 Q226 23 288 68 Q349 105 319 170 Q303 238 217 231 Q105 242 63 191 Z"/></clipPath></defs><ellipse cx="192" cy="136" rx="191" ry="135" fill="url(#earth)"/><g clip-path="url(#rim)">']
for _ in range(190):
    x,y=rng.uniform(40,345),rng.uniform(35,244)
    radius=rng.uniform(1,6)
    color=rng.choice(['#937348','#514235','#ad8a59','#382e26'])
    soil.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{radius:.1f}" ry="{radius*0.65:.1f}" fill="{color}" opacity="0.5"/>')
soil.append('</g><path d="M85 118 Q100 72 160 72 Q230 52 275 87 Q313 116 289 164 Q275 205 214 201 Q129 209 94 175 Z" fill="url(#cavity)"/><g fill="none" stroke="#977854" stroke-width="1.6" stroke-opacity="0.43"><path d="M72 86 Q101 79 109 109 L133 105 M108 109 L102 143"/><path d="M278 66 Q277 93 300 117 L294 143 M300 117 L325 124"/><path d="M116 205 Q154 217 168 202 L178 223"/></g></svg>')
(out/'nursery_earth.svg').write_text(''.join(soil),encoding='utf-8')
print('ANTZENPILE_VECTOR_PROOF_OK')
