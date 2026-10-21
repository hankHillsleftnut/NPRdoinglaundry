# Part 20 · pill: the three heights a pill can sit at (surfaces ladder): wash 0.5, raised 2, lit 5.
# Drawn from tokens only; glyphs are the shipped 20pt icons (icons/outlined-20.json) at 16.
import json
from review import *
I = json.load(open('../icons/outlined-20.json'))
def glyph(name, px, color):
    return f'<svg width="{px}" height="{px}" viewBox="0 0 24 24" style="flex-shrink:0"><path fill="{color}" fill-rule="evenodd" d="{I[name]}"/></svg>'
TIER = {
 'neutral': dict(h=32, bg=C('surface-wash'), bgp=C('surface-wash-pressed'), fg=C('text-primary'), w=V('font-weight-medium'),
                 shadow='none', shadowp='none'),
 'raised': dict(h=32, bg=C('surface-secondary-action'), bgp=C('surface-secondary-action'), fg=C('text-primary'), w=V('font-weight-semibold'),
                shadow=(f'inset 0 1px 0 {C("depth-stroke-inner-top")}, inset 0 0 0 1px {C("depth-stroke-inner")}, 0 0 0 0.5px {C("depth-stroke-outer")}, '
                        f'0 1px 1.5px {C("depth-shadow-contact")}, 0 4px 6px -2px {C("depth-shadow-cast")}'),
                shadowp=(f'inset 0 1px 0 {C("depth-stroke-inner-top")}, inset 0 0 0 1px {C("depth-stroke-inner")}, 0 0 0 0.5px {C("depth-stroke-outer")}, '
                         f'0 0.5px 1px {C("depth-shadow-contact")}, 0 1px 2px -1px {C("depth-shadow-cast")}')),
 'lit': dict(h=48, bg=f'linear-gradient(180deg, {C("glow-primary-gradient-top")}, {C("glow-primary-gradient-bottom")})',
             bgp=f'linear-gradient(180deg, {C("glow-primary-gradient-top-pressed")}, {C("glow-primary-gradient-bottom-pressed")})',
             fg=C('glow-primary-foreground'), w=V('font-weight-semibold'),
             shadow=(f'inset 0 1px 0 {C("glow-primary-rim")}, inset 0 0 12px {C("glow-primary-bloom")}, inset 0 -1px 2px {C("glow-primary-edge")}, '
                     f'0 0 0 2px {C("glow-primary-ring")}, 0 0 16px {C("glow-primary-halo")}, 0 2px 2px {C("shadow-primary-action-3")}, 0 10px 18px -6px {C("depth-tint-primary")}'),
             shadowp=(f'inset 0 1px 0 {C("glow-primary-rim")}, inset 0 -1px 2px {C("glow-primary-edge")}, '
                      f'0 0 0 2px {C("glow-primary-ring")}, 0 0 10px {C("glow-primary-halo")}, 0 1px 1px {C("shadow-primary-action-3")}, 0 2px 3px -1px {C("depth-tint-primary")}')),
}
def pill(tier, label, icon, state='rest', guide=False):
    t = TIER[tier]; h = t['h']; big = h == 48
    pressed = state == 'pressed'
    ring = f'0 0 0 2px {C("background-canvas")}, 0 0 0 4px {C("border-focus")}' if state == 'focused' else ''
    sh = t['shadowp'] if pressed else t['shadow']
    shadow = ', '.join(x for x in ([] if sh == 'none' else [sh]) + ([ring] if ring else [])) or 'none'
    # icon side 8 so the 16 glyph sits on the cap's own centre; label side 12; lit (compact primary, 48): 16 / 20
    pad = f'0 {V("spacing-5")} 0 {V("spacing-4")}' if big else f'0 {V("spacing-3")} 0 {V("spacing-2")}'
    body = (f'<div layer-name="c:pill/{tier}/{state}" style="height:{h}px;border-radius:{V("radius-control")};background:{t["bgp"] if pressed else t["bg"]};'
            f'box-shadow:{shadow};display:flex;align-items:center;gap:{V("spacing-1")};padding:{pad};flex-shrink:0;transform:scale({0.96 if pressed else 1})">'
            + glyph(icon, 20 if big else 16, t['fg'] if tier == 'lit' else C('icon-default'))
            + f'<div style="font-family:{V("font-label")};font-size:{V("text-base") if big else V("text-md")};font-weight:{t["w"]};line-height:{V("leading-tight")};'
              f'letter-spacing:{V("tracking-label")};color:{t["fg"]};white-space:nowrap'
            + (f';text-shadow:0 1px 1px {C("shadow-on-accent-text-1")}' if tier == 'lit' else '') + f'">{label}</div></div>')
    hit = max(44, h)
    return (f'<div layer-name="hit area {hit}" style="height:{hit}px;display:flex;align-items:center;flex-shrink:0'
            + (f';outline:0.5px dashed {C("text-link")};outline-offset:-0.5px' if guide else '') + f'">{body}</div>')
def mag(inner, w, h, k=3):  # a true 1x pill, scaled: every value inside stays a token; the frame is a frame size
    return (f'<div style="width:{w*k}px;height:{h*k}px;position:relative;flex-shrink:0">'
            f'<div style="position:absolute;left:0;top:0;transform:scale({k});transform-origin:0 0">{inner}</div></div>')
W = {'chapters': 92, 'add a source': 120, 'continue': 122}
ROW = [('neutral', 'chapters', 'chapters'), ('raised', 'add a source', 'add'), ('lit', 'continue', 'arrow-right')]
vis = ''.join(tile(mag(pill(t, l, i, guide=True), W[l], max(44, TIER[t]['h'])), f'3× · {t} · rest' + {'neutral': ' · wash 0.5, no stroke, no shadow', 'raised': ' · raised 2: cream, double stroke, contact + cast',
                                                       'lit': ' · lit 5: glow stack, its own sky cast'}[t]) for t, l, i in ROW)
extra = ''
for t, l, i in ROW:
    extra += tile(f'<div style="display:flex;gap:{V("spacing-3")};align-items:center">' + ''.join(pill(t, l, i, st) for st in ('rest', 'pressed', 'focused')) + '</div>',
                f'1× · {t} · rest · pressed · focused')
extra += tile(f'<div style="display:flex;gap:{V("spacing-3")};align-items:center">' + pill('neutral', 'not right', 'correct') + pill('neutral', 'why it\'s here', 'guess')
            + pill('raised', 'retry', 'retry') + pill('raised', 'connect', 'calendar') + '</div>', '1× · in use: the brief sheet\'s neutral pair; raised retry and connect')
rows = {
 'purpose': ('✓', 'one shape, three heights: neutral offers a light choice (chapters, not right), raised is the real secondary action (add, connect, retry), lit is the one next step'),
 'colour': ('✓', 'neutral surface.wash; raised surface.secondaryAction (cream), never blue; lit glow.primary, the only blue (surfaces "where blue goes")'),
 'type': ('✓', 'Geist label (font.label), not mono (screen rule 4); 14 medium on neutral, 14 semibold on raised (rule 15), 16 semibold on lit; leading.tight, tracking.label; lowercase verbs and nouns'),
 'space': ('✓', '32 tall; icon side 8 so the 16 glyph sits on the cap\'s centre, label side 12, 4 between; lit 48 with 16 / 20'),
 'shape': ('✓', 'true pills: radius.control (height / 2); no inner wells, so nothing to make concentric'),
 'depth': ('✓', 'one level each: wash 0.5 flat; raised 2 = inner white stroke brighter on top, 0.5 warm hairline, contact 0 1 1.5 + cast 0 4 6 −2; lit 5 = rim, bloom, lower edge, 2pt ring, halo, sky cast'),
 'texture': ('—', 'under 44pt tall: no grain (lit adds grain only at 60, the hero button)'),
 'icon': ('✓', 'every glyph is a shipped inked icon at its 20pt optical size, drawn 16 in pills and 20 in the lit pill; tinted icon.default, white on lit'),
 'tokens': ('✓', 'surface.wash(.pressed), surface.secondaryAction, depth.stroke.*, depth.shadow.contact/cast, glow.primary.*, depth.tint.primary, radius.control, font.label, text.md/base'),
 'optical centring': ('✓', 'label set on line-height 1 and centred on its x-height; the asymmetric padding (8 / 12) balances the glyph\'s soft edge against the text\'s hard one'),
 'contrast': ('✓', 'text.primary on wash ≈ 16 : 1; on cream ≈ 17 : 1; white on the sky gradient ≥ 4.5 : 1 at the bottom stop (checked by contrast-pairs)'),
 'hit area': ('✓', '44 tall around every 32 visual (dashed blue at 3×); the pill is always wider than 44; lit is 48, already over'),
 'states': ('✓', 'rest, pressed, focused drawn; neutral darkens to wash.pressed, raised sinks its shadow (stays on its level), lit takes the pressed gradient and drops the bloom; disabled only for lit, with a reason beside it'),
 'motion': ('✓', 'press scale 0.96 in 80ms, back 240ms on the spring; lit fade 200ms when focused; Reduce Motion: no scale'),
 'haptic': ('✓', 'lit: haptic.press on touch down; neutral and raised: none (they are light choices)'),
 'goals': ('✓', 'a quiet page with one lit next step (rule 5); secondary actions obvious by depth, not colour (rule 15)'),
 'wireframe': ('✓', 'matches the mid-fi\'s pill row under the brief and the raised "connect / add" pills in onboarding'),
}
open('p20.html', 'w').write(part(20, 'pill · neutral · raised · lit', 'one shape at three heights; height says how much it asks', vis, rows,
     'ready for your review. one question: should the lit pill be 48 (the compact primary, as drawn) or match the others at 32 with a glow?'))
open('p20_extra.html', 'w').write(extra)
print(len(open('p20.html').read()), len(extra))
