# Part 40 · episode tiles for Podcasts (PC-1): the hero tile (this week's episode) and the square tile (briefs, earlier episodes).
# Same family as brief card D (raised paper, token mesh artwork, inky title); rule 19: episodes and briefs are tiles, not rows.
# Only the hero carries the lit play (one lit object per screen); a square tile opens the player when tapped.
import importlib.util
from review import V, C
from review2 import _t, _kicker
def load(n):
    spec = importlib.util.spec_from_file_location(n, f'{n}.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
b = load('p03_briefcard')
# artwork meshes from palette tokens, one per kind, so the grid reads at a glance (no generated images)
MESH = {
 'weekly': (C('night-700'), f'radial-gradient(circle farthest-corner at 85% 15% in oklab, {C("amber-300")} 0%, transparent 55%), radial-gradient(circle farthest-corner at 0% 100% in oklab, {C("night-900")} 0%, transparent 80%)'),
 'brief':  (C('sky-500'), f'radial-gradient(circle farthest-corner at 85% 10% in oklab, {C("amber-300")} 0%, transparent 55%), radial-gradient(circle farthest-corner at 0% 100% in oklab, {C("sky-800")} 0%, transparent 80%)'),
 'first':  (C('green-600'), f'radial-gradient(circle farthest-corner at 80% 10% in oklab, {C("amber-200")} 0%, transparent 55%), radial-gradient(circle farthest-corner at 0% 100% in oklab, {C("green-900")} 0%, transparent 80%)'),
 'calls':  (C('paper-450'), f'radial-gradient(circle farthest-corner at 85% 10% in oklab, {C("amber-200")} 0%, transparent 55%), radial-gradient(circle farthest-corner at 0% 100% in oklab, {C("paper-700")} 0%, transparent 80%)'),
}
def art(kind, h, label=None, play=False):
    base, img = MESH[kind]
    lab = (f'<div style="position:absolute;left:{V("spacing-4")};top:{V("spacing-3")};font-family:{V("font-label")};font-weight:{V("font-weight-medium")};'
           f'font-size:{V("text-sm")};color:{C("glow-primary-foreground")}">{label}</div>') if label else ''
    p = f'<div style="position:absolute;right:{V("spacing-4")};bottom:-22px">{b.lit_play()}</div>' if play else ''
    return (f'<div layer-name="artwork · mesh · {kind}" style="height:{h}px;border-radius:{V("radius-panel")};position:relative;'
            f'background-color:{base};background-image:{img}">{lab}{p}</div>')
def hero(title, meta, kind='weekly', label='this week · 12 min', state='rest', w=354):
    play = state == 'rest'
    sub = (_t(meta, 'text-md', 'text-secondary') if state != 'making' else
           f'<div style="display:flex;align-items:center;gap:{V("spacing-2")}">' + _t('being made · ready sunday 9:00', 'text-md', 'text-label', 'font-label') + '</div>')
    return (f'<div layer-name="c:episode-tile/hero/{state}" style="width:{w}px;display:flex;flex-direction:column;gap:{V("spacing-3")};padding:{V("spacing-2")};{b.RAISED}">'
            + art(kind, 180, label, play)
            + f'<div style="display:flex;flex-direction:column;gap:{V("spacing-1")};padding:{V("spacing-2")} {V("spacing-2")} {V("spacing-2")}">'
            + b.headline(title, 'text-2xl', clear=True) + sub + '</div></div>')
def square(title, meta, kind, w=171):
    return (f'<div layer-name="c:episode-tile/square/rest" style="width:{w}px;display:flex;flex-direction:column;gap:{V("spacing-2")};padding:{V("spacing-2")};{b.RAISED}">'
            + art(kind, w - 16)
            + f'<div style="display:flex;flex-direction:column;gap:{V("spacing-1")};padding:{V("spacing-1")} {V("spacing-1")} {V("spacing-2")}">'
            + f'<div style="font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-card")};font-size:{V("text-base")};line-height:{V("leading-tight")};'
              f'letter-spacing:{V("tracking-card")};color:{C("text-primary")};text-wrap:balance;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden">{title}</div>'
            + _t(meta, 'text-sm', 'text-label', 'font-label') + '</div></div>')
HERO = hero('the week you stopped rushing', 'mornings, the standup, sleep')
# being made: one compact row (founder on JR-1: "the brief loading should be much smaller"), the grey syncing ring, no play
MAKING = (f'<div layer-name="c:episode-tile/hero/making" style="width:354px;display:flex;align-items:center;gap:{V("spacing-3")};padding:{V("spacing-3")} {V("spacing-4")};{b.RAISED}">'
          + _t("this week's episode", 'text-md', 'text-primary', 'font-label', 'font-weight-medium') + '</div>')
SQ = [square("today's brief", 'tue 21 oct · 4 min', 'brief'), square('your first episode', 'sun 12 oct · 5 min', 'first'),
      square('what the sunday calls keep coming back to', 'sun 19 oct · 11 min', 'calls'), square("monday's brief", 'mon 20 oct · 3 min', 'brief')]
def grid(*tiles): return f'<div style="display:flex;flex-wrap:wrap;gap:{V("spacing-3")};width:354px">' + ''.join(tiles) + '</div>'
open('p40_hero.html', 'w').write(HERO)
open('p40_making.html', 'w').write(MAKING)
open('p40_grid.html', 'w').write(grid(*SQ))
