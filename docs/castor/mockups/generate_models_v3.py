"""Generates colorful variants from the v2 SVGs and an obstacles study.

Run after generate_models.py. Does not change the originals or the v2 files.
Text drawn inside the images stays in Portuguese (child-facing concept art).
"""
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent
PALETTE = {
    '#BE8050': '#FFB13B', '#75432F': '#EB762F', '#C59465': '#FFE497',
    '#684738': '#A85439', '#9D7351': '#ECA15B', '#97623F': '#EC893A',
    '#D4A17A': '#FFB0A0', '#B67D50': '#FFC24B', '#E7C697': '#FFF0BA',
    '#AA7049': '#F79632', '#51372D': '#843C32',
    '#A18164': '#BA9AF2', '#59453C': '#8262C5', '#4D4038': '#554378',
    '#C6A47A': '#FFE48A', '#705443': '#9371CF', '#A58766': '#D8BDF8',
    '#F0DDB4': '#FFF2D1', '#D0B385': '#FFD681', '#C58E3F': '#FFB93F',
    '#947354': '#D29548', '#A7733B': '#E9A039',
    '#94674E': '#67D4CD', '#53392F': '#269DAB', '#45352D': '#255F69',
    '#624535': '#258D9F', '#DCC099': '#FFF0C8', '#84583F': '#40B6BF',
    '#C79D7A': '#FFB9B1', '#E9CEAA': '#FFF1D5', '#896047': '#45BCC3',
    '#F7F2E8': '#EFF9F7', '#E1D9CA': '#C9DEDB',
    '#A6B875': '#A7CF77', '#74B9C5': '#65CADD',
}

for file in ROOT.glob('*-v2.svg'):
    content = file.read_text(encoding='utf-8')
    for old, new in PALETTE.items():
        content = content.replace(old, new)
    # Slightly larger cheeks and eyes, keeping the silhouettes.
    content = content.replace('<ellipse cx="-14" cy="-13"', '<ellipse cx="-24" cy="0" rx="5" ry="3" fill="#F88780" stroke="none"/><ellipse cx="31" cy="0" rx="5" ry="3" fill="#F88780" stroke="none"/><ellipse cx="-14" cy="-13"')
    content = content.replace('rx="5" ry="7"', 'rx="6" ry="8"')
    content = content.replace('rx="4.5" ry="6"', 'rx="5.5" ry="7"')
    content = content.replace('DIREÇÃO VISUAL 02', 'DIREÇÃO VISUAL 03')
    content = content.replace('Três amigos. Três silhuetas.', 'Um vale cheio de cor!')
    content = content.replace('Formas simples, materiais quentes e expressões legíveis no pequeno vale.', 'Laranja e mel · lilás e amarelo · turquesa e creme. Amigos prontos para descobrir!')
    content = content.replace('fill="#FFFCF5" stroke=', 'fill="#FFF1DC" stroke=', 1)
    content = content.replace('fill="#FFFCF5" stroke=', 'fill="#F0E8FF" stroke=', 1)
    content = content.replace('fill="#FFFCF5" stroke=', 'fill="#E1F7F1" stroke=', 1)
    content = content.replace('v2', 'v3')
    file.with_name(file.name.replace('-v2.svg', '-v3.svg')).write_text(content, encoding='utf-8')

cards = [
    ('Galho muito grosso', 'É forte, mas não cabe!', 'Roer no ponto marcado', 'O galho passa a caber no encaixe.',
     '<rect x="48" y="75" width="220" height="57" rx="26" fill="#B87439"/><ellipse cx="258" cy="103" rx="19" ry="28" fill="#FFDB8C"/><ellipse cx="258" cy="103" rx="10" ry="17" fill="none" stroke="#BA803D" stroke-width="3"/><path d="M157 70V139" stroke="#FFF9D6" stroke-width="5" stroke-dasharray="7 6"/><path d="M96 88L133 88M82 118L125 118" stroke="#D89952" stroke-width="5" stroke-linecap="round"/>'),
    ('Galho estragado', 'Tem fissuras e está mole.', 'Escolher um galho firme', 'Deixar este no chão da floresta.',
     '<path d="M48 87Q150 72 265 94L257 129Q151 113 52 130Z" fill="#987153"/><path d="M138 83L124 99L147 106L132 124M211 90L199 108L212 120" fill="none" stroke="#493F37" stroke-width="5"/><circle cx="82" cy="105" r="8" fill="#594837"/><circle cx="231" cy="109" r="6" fill="#594837"/><path d="M66 79Q76 58 88 79M217 85Q229 63 241 86" fill="#BDCD87"/>'),
    ('Ramo preso', 'Uma pedrinha prende a ponta.', 'Afastar a pedra e puxar', 'O caminho fica livre para levar.',
     '<path d="M60 120L259 89M161 106L187 64" stroke="#B77B43" stroke-width="16" stroke-linecap="round"/><path d="M52 128Q36 90 72 84Q110 80 123 125Z" fill="#A3B8C4" stroke="#607F91" stroke-width="3"/><path d="M72 67Q95 44 125 55M114 45L128 55L116 65" fill="none" stroke="#278B87" stroke-width="4" stroke-linecap="round"/>'),
]
body = '<rect width="1140" height="510" fill="#F1F8ED"/><g font-family="Segoe UI, sans-serif" fill="#284B43"><text x="42" y="53" font-size="30" font-weight="700">Pequenos desafios, grandes descobertas</text><text x="42" y="86" font-size="17">Observar → experimentar → resolver. Sem pressa e com ajuda quando for preciso.</text></g>'
for i, (title, clue, action, outcome, drawing) in enumerate(cards):
    x = 30 + i * 370
    body += f'<g transform="translate({x} 116)"><rect width="350" height="315" rx="22" fill="#FFFFFF" stroke="#D0DED2"/>{drawing}<g font-family="Segoe UI, sans-serif" fill="#284B43"><text x="22" y="35" font-size="22" font-weight="700">{escape(title)}</text><text x="22" y="167" font-size="16">{escape(clue)}</text><rect x="20" y="189" width="310" height="47" rx="16" fill="#FFE69A"/><text x="175" y="219" text-anchor="middle" font-size="18" font-weight="650">{escape(action)}</text><text x="22" y="277" font-size="15">{escape(outcome)}</text></g></g>'
body += '<text x="42" y="473" font-family="Segoe UI, sans-serif" font-size="15" fill="#476258">Proposta de interação · pistas por forma e voz · sem perder materiais · ajuda opcional da coruja</text>'
(ROOT / 'obstacles-v3.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1140 510" role="img"><title>Três obstáculos leves para a construção da represa</title>' + body + '</svg>', encoding='utf-8')
print('Generated: eight colorful v3 SVGs and an obstacles board.')
