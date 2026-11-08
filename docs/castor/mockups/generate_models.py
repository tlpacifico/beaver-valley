"""Generates the v2 SVG studies with no dependencies; keeps the original mockups.

Run: python docs/castor/mockups/generate_models.py
Character groups use local coordinates, with the feet near y=90.
Text drawn inside the images stays in Portuguese (child-facing concept art).
"""
from pathlib import Path
import re
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent
DEFS = '''<defs>
  <linearGradient id="pelagem" x2=".8" y2="1"><stop stop-color="#BE8050"/><stop offset="1" stop-color="#75432F"/></linearGradient>
  <linearGradient id="penas" x2=".8" y2="1"><stop stop-color="#A18164"/><stop offset="1" stop-color="#59453C"/></linearGradient>
  <linearGradient id="lontra-pelo" x2=".6" y2="1"><stop stop-color="#94674E"/><stop offset="1" stop-color="#53392F"/></linearGradient>
</defs>'''

BEAVER = '''<g stroke="#51372D" stroke-width="2.5" stroke-linejoin="round">
  <ellipse cx="0" cy="91" rx="67" ry="10" fill="#352E25" opacity=".12" stroke="none"/>
  <path d="M-29 60 C-62 33-104 45-88 71 C-79 88-52 91-27 79Z" fill="#684738"/>
  <path d="M-85 58L-54 80M-73 50L-40 77M-88 69L-63 50M-75 80L-49 57" fill="none" stroke="#9D7351" stroke-width="2"/>
  <ellipse cx="0" cy="43" rx="43" ry="47" fill="url(#pelagem)"/>
  <ellipse cx="8" cy="48" rx="26" ry="32" fill="#C59465" stroke="none"/>
  <path d="M-27 78Q-48 80-39 91L-9 91Q-2 83-13 79M19 79Q9 88 18 92L46 92Q54 84 35 79" fill="#684738"/>
  <circle cx="-23" cy="-35" r="12" fill="#97623F"/><circle cx="30" cy="-35" r="11" fill="#97623F"/>
  <circle cx="-23" cy="-35" r="6" fill="#D4A17A" stroke="none"/><circle cx="30" cy="-35" r="5" fill="#D4A17A" stroke="none"/>
  <path d="M-36-17Q-33-43 2-42Q36-42 44-15Q52 17 18 23L-17 19Q-41 14-36-17Z" fill="url(#pelagem)"/>
  <path d="M-10-36L-5-43L3-38L11-44L17-36" fill="#B67D50" stroke="none"/>
  <ellipse cx="-14" cy="-13" rx="5" ry="7" fill="#292723" stroke="none"/><ellipse cx="24" cy="-14" rx="5" ry="7" fill="#292723" stroke="none"/>
  <circle cx="-12" cy="-15" r="1.7" fill="#FFF8EA" stroke="none"/><circle cx="26" cy="-16" r="1.7" fill="#FFF8EA" stroke="none"/>
  <path d="M-22 2Q-16-12 3-4Q24-15 34 0Q37 15 7 17Q-22 17-22 2" fill="#E7C697" stroke="none"/>
  <path d="M-3-5Q6-11 15-5Q13 3 6 4Q0 3-3-5" fill="#3D302B" stroke="none"/>
  <rect x="-2" y="12" width="8" height="13" rx="2" fill="#FFF5D7" stroke-width="1"/><rect x="6" y="12" width="8" height="13" rx="2" fill="#FFF5D7" stroke-width="1"/>
  <path d="M-9 9Q6 17 22 7" fill="none" stroke-width="1.8"/>
  <path d="M-37 31Q-49 45-23 54Q-13 50-23 43M35 29Q52 40 31 54Q20 51 31 41" fill="#AA7049"/>
</g>'''

OWL = '''<g stroke="#4D4038" stroke-width="2.5" stroke-linejoin="round">
  <ellipse cx="0" cy="91" rx="46" ry="8" fill="#352E25" opacity=".12" stroke="none"/>
  <path d="M-17 76L-18 89M-18 85L-26 90M-18 85L-10 90M17 76L18 89M18 85L10 90M18 85L26 90" fill="none" stroke="#A7733B" stroke-width="5" stroke-linecap="round"/>
  <path d="M-43-11Q-45-50 0-50Q45-50 43-11L45 39Q45 80 0 82Q-45 80-45 39Z" fill="url(#penas)"/>
  <path d="M-27 18Q0 0 27 18L29 53Q23 76 0 77Q-23 76-29 53Z" fill="#C6A47A" stroke="none"/>
  <path d="M-38 2Q-62 33-37 68Q-21 57-26 29M38 2Q62 33 37 68Q21 57 26 29" fill="#705443"/>
  <path d="M-33 32L-40 44M-32 44L-37 55M33 32L40 44M32 44L37 55" fill="none" stroke="#A58766"/>
  <path d="M0-27C-33-55-52-11-27 10L0 30L27 10C52-11 33-55 0-27Z" fill="#F0DDB4" stroke="none"/>
  <ellipse cx="-18" cy="-8" rx="13" ry="16" fill="#D0B385" stroke="none"/><ellipse cx="18" cy="-8" rx="13" ry="16" fill="#D0B385" stroke="none"/>
  <ellipse cx="-18" cy="-8" rx="8" ry="11" fill="#302E28" stroke="none"/><ellipse cx="18" cy="-8" rx="8" ry="11" fill="#302E28" stroke="none"/>
  <circle cx="-15" cy="-12" r="3" fill="#FFFBEA" stroke="none"/><circle cx="21" cy="-12" r="3" fill="#FFFBEA" stroke="none"/>
  <path d="M-7 7Q0 1 7 7L0 20Z" fill="#C58E3F" stroke-width="1.5"/>
  <path d="M-14 37L-10 43L-6 37M7 37L11 43L15 37M-5 52L0 58L5 52M-15 61L-12 66M14 61L11 66" fill="none" stroke="#947354" stroke-linecap="round"/>
</g>'''

OTTER = '''<g stroke="#45352D" stroke-width="2.5" stroke-linejoin="round">
  <ellipse cx="5" cy="92" rx="83" ry="9" fill="#352E25" opacity=".12" stroke="none"/>
  <path d="M25 60C63 62 59 89 103 66C86 99 42 103 9 79Z" fill="#624535"/>
  <path d="M-26 10C-37 37-40 65-23 82Q-5 96 21 80C39 67 17 31 21 5Z" fill="url(#lontra-pelo)"/>
  <path d="M-18 8Q-27 48-13 69Q0 81 13 65L10 8Z" fill="#DCC099" stroke="none"/>
  <path d="M-23 77Q-43 82-34 91L-10 91Q-5 86-14 80M13 78Q2 88 13 92L38 92Q45 85 25 80" fill="#624535"/>
  <circle cx="-29" cy="-29" r="9" fill="#84583F"/><circle cx="24" cy="-31" r="9" fill="#84583F"/>
  <circle cx="-29" cy="-29" r="4" fill="#C79D7A" stroke="none"/><circle cx="24" cy="-31" r="4" fill="#C79D7A" stroke="none"/>
  <path d="M-36-16Q-35-39-7-40Q23-43 32-20Q44 5 16 16L-12 17Q-38 12-36-16Z" fill="url(#lontra-pelo)"/>
  <ellipse cx="-18" cy="-14" rx="4.5" ry="6" fill="#292723" stroke="none"/><ellipse cx="17" cy="-16" rx="4.5" ry="6" fill="#292723" stroke="none"/>
  <circle cx="-16.5" cy="-16" r="1.5" fill="#FFF8EA" stroke="none"/><circle cx="18.5" cy="-18" r="1.5" fill="#FFF8EA" stroke="none"/>
  <path d="M-25 0Q-19-12-3-4Q17-16 27-4Q38 12 1 18Q-26 17-25 0Z" fill="#E9CEAA" stroke="none"/>
  <path d="M-10-5Q-1-10 9-6Q10 1 0 4Q-9 3-10-5Z" fill="#352D29" stroke="none"/>
  <path d="M0 4L1 9M-9 8Q0 16 12 6M-21 0L-43-4M-22 6L-44 8M22-2L41-8M24 4L46 3" fill="none" stroke-width="1.5" stroke-linecap="round"/>
  <path d="M-28 29Q-49 44-32 51L-15 42M18 27Q43 32 34 45L18 39" fill="#896047"/>
</g>'''

ANIMALS = {'beaver': BEAVER, 'owl': OWL, 'otter': OTTER}
# Portuguese names drawn inside the images.
LABELS = {'beaver': 'Castor', 'owl': 'Coruja', 'otter': 'Lontra'}

def svg(body, width, height, title):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" role="img" aria-labelledby="title"><title id="title">{escape(title)}</title>{DEFS}{body}</svg>\n'

def animal(name, x, y, scale):
    return f'<g transform="translate({x} {y}) scale({scale})">{ANIMALS[name]}</g>'

for name, drawing in ANIMALS.items():
    (ROOT / f'{name}-model-v2.svg').write_text(svg(f'<g transform="translate(160 105) scale(1.25)">{drawing}</g>', 320, 240, f'{LABELS[name]} — estudo vetorial v2'), encoding='utf-8')

body = '<rect width="1200" height="650" fill="#F7F2E8"/><g font-family="Segoe UI, sans-serif" fill="#393B30"><text x="56" y="58" font-size="14" letter-spacing="3">O CASTOR / DIREÇÃO VISUAL 02</text><text x="56" y="105" font-size="34" font-weight="650">Três amigos. Três silhuetas.</text><text x="56" y="137" font-size="17" fill="#6E7160">Formas simples, materiais quentes e expressões legíveis no pequeno vale.</text></g>'
for i, (name, subtitle, notes) in enumerate([
    ('beaver', 'O construtor curioso', ['Corpo robusto · cauda achatada', 'Dentes visíveis · patas curtas']),
    ('owl', 'A observadora tranquila', ['Disco facial · asas recolhidas', 'Olhar atento · penas em massas']),
    ('otter', 'A exploradora brincalhona', ['Corpo alongado · cauda afilada', 'Focinho claro · pose flexível']),
]):
    x = 40 + i * 390
    body += f'<rect x="{x}" y="172" width="370" height="422" rx="22" fill="#FFFCF5" stroke="#E1D9CA"/>'
    body += animal(name, x + 181, 292, 1.45)
    body += f'<g font-family="Segoe UI, sans-serif" fill="#393B30"><text x="{x+24}" y="468" font-size="26" font-weight="650">{LABELS[name]}</text><text x="{x+24}" y="495" font-size="16" fill="#7F6147">{subtitle}</text>'
    for j, note in enumerate(notes):
        body += f'<text x="{x+24}" y="{536+j*24}" font-size="15">{note}</text>'
    body += '</g>'
body += '<text x="56" y="627" font-family="Segoe UI, sans-serif" font-size="13" fill="#6E7160">PROPOSTA · Estudos 2D editáveis para orientar a modelação 3D. Sem roupa ou acessórios obrigatórios.</text>'
(ROOT / 'characters-v2.svg').write_text(svg(body, 1200, 650, 'Castor, coruja e lontra — proposta visual'), encoding='utf-8')

# Self-contained copies: the SVGs keep working in Markdown viewers.
# Each entry: output file stem, Portuguese title kept inside the image, character placements.
placements = {
    'valley-map': ('vale-mapa', [('beaver', 262, 182, .29), ('otter', 466, 153, .25), ('owl', 118, 110, .22)]),
    'camera-diorama': ('camara-diorama', [('beaver', 129, 113, .25)]),
    'dam-a-collect-and-fit': ('represa-a-recolher-encaixar', [('beaver', 97, 141, .29)]),
    'dam-b-free-build': ('represa-b-construcao-livre', [('beaver', 159, 75, .25)]),
}
for filename, (image_title, characters) in placements.items():
    content = (ROOT / f'{filename}.svg').read_text(encoding='utf-8')
    if '<defs>' in content:
        content = content.replace('</defs>', DEFS[6:-7] + '</defs>', 1)
    else:
        content = content.replace('>', '>' + DEFS, 1)
    matches = list(re.finditer(r'<g transform="translate\([^\"]+\)">.*?</g>', content, re.S))
    if len(matches) != len(characters):
        raise ValueError(f'{filename}: expected {len(characters)} groups, found {len(matches)}')
    for match, (name, x, y, scale) in reversed(list(zip(matches, characters))):
        content = content[:match.start()] + animal(name, x, y, scale) + content[match.end():]
    content = content.replace('#8fd16a', '#A6B875').replace('#5bb3e8', '#74B9C5').replace('#ffd54f', '#E7BC61').replace('#ffb74d', '#D9A15B').replace('#ff8a65', '#C8825B')
    content = content.replace('>', f'><title>{image_title} — personagens v2</title>', 1)
    (ROOT / f'{filename}-v2.svg').write_text(content, encoding='utf-8')

print('Generated: 3 characters, 1 board and 4 v2 mockups.')
