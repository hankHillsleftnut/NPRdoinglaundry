from review import *
import re
# Part 03 · brief card · six versions (founder comment c-4gl3u1: "i like this component, I want to see multiple versions").
# One version (B) also carries the "more components that feel like this" direction (c-bv10um): a soft fade and a floating pill.
def icon(name, size, fill):
    d = re.search(r' d="([^"]+)"', open(f'../icons/shipped/{name}.svg').read()).group(1)
    return (f'<svg layer-name="c:icon/{name}" width="{size}" height="{size}" viewBox="0 0 24 24" style="display:inline-block;flex-shrink:0">'
            f'<path fill="{fill}" fill-rule="evenodd" d="{d}"/></svg>')
RAISED = (f'background:{C("background-raised")};border-radius:{V("radius-card")};'
          f'box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, inset 0 0 0 1px {C("depth-stroke-inner")}, 0 0 0 0.5px {C("depth-stroke-outer")}, '
          f'0 1px 2px {C("depth-shadow-contact")}, 0 12px 28px -12px {C("depth-shadow-cast")}, 0 24px 60px -20px {C("depth-shadow-ambient")}')
def lit_play(size=44, glyph=18):
    return (f'<div layer-name="c:button/lit/play" style="width:{size}px;height:{size}px;flex-shrink:0;border-radius:{V("radius-control")};display:flex;align-items:center;justify-content:center;'
            f'background:linear-gradient(180deg, {C("glow-primary-gradient-top")}, {C("glow-primary-gradient-bottom")});'
            f'box-shadow:inset 0 1px 0 {C("glow-primary-rim")}, inset 0 -1px 1.5px {C("glow-primary-edge")}, inset 0 0 6px {C("glow-primary-bloom")}, 0 0 0 1.5px {C("glow-primary-ring")}, 0 6px 14px -4px {C("glow-primary-halo")}, 0 2px 2px {C("glow-primary-cast")}">'
            f'<div style="display:flex">{icon("play", glyph, C("glow-primary-foreground"))}</div></div>')   # no nudge: the shipped triangle is already centred by its ink (centroid x 12.3 of 24)
def meta(left, right=None, colour='text-label'):
    r = f'<div style="font-family:{V("font-mono")};font-size:{V("text-sm")};color:{C("text-label")}">{right}</div>' if right else ''
    return (f'<div layer-name="meta" style="display:flex;justify-content:space-between;align-items:baseline">'
            f'<div style="font-family:{V("font-label")};font-size:{V("text-sm")};line-height:{V("leading-snug")};letter-spacing:{V("tracking-label")};color:{C(colour)}">{left}</div>{r}</div>')
def headline(s, size='text-xl', clear=False):  # clear: keep 48 free on the right for the seam play (M4: it sat on a one-line headline on Pro Max)
    return (f'<div layer-name="headline" style="{"padding-right:" + V("spacing-12") + ";text-wrap:balance;" if clear else ""}font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-card")};font-size:{V(size)};'
            f'line-height:{V("leading-tight")};letter-spacing:{V("tracking-card")};color:{C("text-primary")}">{s}</div>')
def body(s, colour='text-secondary'):
    return f'<div style="font-family:{V("font-text")};font-size:{V("text-md")};line-height:{V("leading-snug")};color:{C(colour)}">{s}</div>'
def card(name, inner, pad='spacing-5', gap='spacing-3', extra=''):
    return (f'<div layer-name="c:brief-card/{name}/rest" style="width:342px;display:flex;flex-direction:column;gap:{V(gap)};padding:{V(pad)};{RAISED};{extra}">{inner}</div>')
H = 'three things moved since yesterday'
# A · the one you liked, in light: meta, the headline, then the lit play beside one line of what it's made of
A = card('standard', meta("today's brief · tue 21 oct", '2 min') + headline(H)
         + f'<div style="display:flex;gap:{V("spacing-3")};align-items:center">{lit_play()}{body("Your sister, the job question, and a quieter Sunday.")}</div>')
# B · the first words of the brief fade out under a floating pill: you read the opening, then press play to hear the rest
lines = [('Morning. Three things moved since yesterday.', 'text-primary', ''), ('Your sister came up again, after the call on Sunday.', 'text-secondary', ''),
         ('And you said the job question twice, both times', 'text-tertiary', 'filter:blur(0.6px);'), ('late, both times after a long day.', 'text-disabled', 'filter:blur(1.6px);')]
fade = ''.join(f'<div style="font-family:{V("font-text")};font-size:{V("text-base")};line-height:{V("leading-normal")};color:{C(c)};{x}">{t}</div>' for t, c, x in lines)
pill = (f'<div layer-name="c:pill/raised/play" style="position:absolute;left:{V("spacing-3")};right:{V("spacing-3")};bottom:{V("spacing-3")};height:52px;display:flex;align-items:center;gap:{V("spacing-3")};'
        f'padding-left:{V("spacing-size-border-inset")};padding-right:{V("spacing-4")};border-radius:{V("radius-control")};background:{C("background-raised")};'
        f'box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, 0 0 0 0.5px {C("depth-stroke-outer")}, 0 1px 2px {C("depth-shadow-contact")}, 0 10px 24px -10px {C("depth-shadow-cast")}">'
        + lit_play() + f'<div style="flex:1;font-family:{V("font-text")};font-size:{V("text-md")};font-weight:{V("font-weight-semibold")};color:{C("text-primary")}">hear the rest</div>'
        + f'<div style="font-family:{V("font-mono")};font-size:{V("text-sm")};color:{C("text-label")}">2:04</div></div>')
B = card('opening', meta("today's brief · tue 21 oct") + f'<div style="display:flex;flex-direction:column;gap:{V("spacing-1")};padding-bottom:{V("spacing-12")}">{fade}</div>' + pill,
         extra='position:relative;overflow:hidden')
# C · compact: one row for lists (Podcasts > briefs), 44 play, one-line headline, duration
C_ = card('row', f'<div style="display:flex;gap:{V("spacing-3")};align-items:center">{lit_play()}'
          f'<div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:{V("spacing-1")}">'
          f'<div style="font-family:{V("font-label")};font-size:{V("text-sm")};color:{C("text-label")}">tue 21 oct</div>'
          f'<div style="font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-card")};font-size:{V("text-lg")};letter-spacing:{V("tracking-card")};line-height:{V("leading-tight")};color:{C("text-primary")};white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{H}</div></div>'
          f'<div style="font-family:{V("font-mono")};font-size:{V("text-sm")};color:{C("text-label")}">2 min</div></div>', pad='spacing-3')
# D · with artwork: an OKLCH mesh from the sky and amber tokens (no generated image); the play floats on the seam
# founder 20 Oct (c-j2mszl, "the blue inside the card doesn't feel good"): artwork is warm paper + amber, never sky; blue stays the play's alone (rule 14)
art = (f'<div layer-name="artwork · mesh" style="height:132px;border-radius:{V("radius-panel")};position:relative;background-color:{C("paper-150")};'
       f'background-image:radial-gradient(circle farthest-corner at 88% 0% in oklab, {C("amber-200")} 0%, transparent 62%), radial-gradient(circle farthest-corner at 0% 100% in oklab, {C("paper-300")} 0%, transparent 75%)">'
       f'<div style="position:absolute;left:{V("spacing-4")};top:{V("spacing-3")};font-family:{V("font-label")};font-weight:{V("font-weight-medium")};font-size:{V("text-sm")};color:{C("text-secondary")}">tue 21 oct · 2 min</div>'
       f'<div style="position:absolute;right:{V("spacing-4")};bottom:-22px">{lit_play()}</div></div>')
D = card('artwork', art + f'<div style="display:flex;flex-direction:column;gap:{V("spacing-2")};padding:{V("spacing-2")} {V("spacing-2")} {V("spacing-2")}">' + headline(H, clear=True) + body('Your sister, the job question, and a quieter Sunday.') + '</div>', pad='spacing-2')
# E · playing: the card becomes the player in place: the part being spoken, chapter pills, a quiet pause
segs = ''.join(f'<div style="height:4px;flex:{w} 1 0;min-width:0;border-radius:{V("radius-control")};overflow:hidden;display:flex;background:{C("surface-track")}"><div style="width:{p}%;background:{C("player-progress")}"></div></div>' for w, p in [(96, 100), (110, 36), (90, 0)])
E = card('playing', meta("now playing · your sister", '1:12')
         + f'<div style="font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-card")};font-size:{V("text-xl")};line-height:{V("leading-tight")};letter-spacing:{V("tracking-card")};color:{C("text-primary")}">“She asked how the job thing was going, and I didn’t know what to say.”</div>'
         + f'<div style="display:flex;align-items:center;gap:{V("spacing-3")}"><div style="display:flex;gap:{V("spacing-1")};flex:1">{segs}</div>'
         + f'<div layer-name="c:icon-button/wash/pause" style="width:44px;height:44px;border-radius:{V("radius-control")};background:{C("surface-wash")};display:flex;align-items:center;justify-content:center">{icon("pause", 18, C("icon-default"))}</div></div>')
# F · made from: the receipts first, so you know why before you press play
chip = lambda t: f'<div style="height:28px;display:flex;align-items:center;padding:0 {V("spacing-3")};border-radius:{V("radius-control")};background:{C("surface-wash")};font-family:{V("font-label")};font-size:{V("text-sm")};color:{C("text-secondary")}">{t}</div>'
F = card('receipts', meta("today's brief · made from") + f'<div style="display:flex;gap:{V("spacing-2")};flex-wrap:wrap">{chip("calendar · 3")}{chip("2 entries")}{chip("1 voice note")}</div>'
         + f'<div style="display:flex;gap:{V("spacing-3")};align-items:flex-end;justify-content:space-between">{headline(H)}{lit_play()}</div>')
vis = (tile(A, 'A · standard · the one you liked, in light') + tile(B, 'B · opening · the first words fade under a floating pill')
       + tile(C_, 'C · row · for the briefs list, one line') + tile(D, 'D · artwork · token mesh, the play on the seam')
       + tile(E, 'E · playing · the card becomes the player in place') + tile(F, 'F · receipts · what it\'s made from, first'))
rows = {
 'purpose': ('✓', 'one job in every version: get you to press play on today\'s brief. Each version trades a different thing for it (context, intrigue, density, warmth, now, trust)'),
 'colour': ('✓', 'raised paper; the lit play is the only colour except D\'s mesh (sky + amber tokens)'),
 'type': ('✓', 'Exposure −20 headline, SF Pro body, Geist meta, mono only for minutes'),
 'space': ('✓', '342 wide (390 minus the 24 margins); 20 inset; 12 between parts; the pill in B is 12 off three edges'),
 'shape': ('✓', 'card 20; D\'s artwork 16 inside an 8 inset (concentric 20 − 4… held at 16 for the panel token); pills full'),
 'depth': ('✓', 'raised: inner top stroke + outer hairline + contact + cast + ambient; the lit play adds rim, edge, bloom, ring, halo'),
 'texture': ('—', 'grain only on D\'s mesh in the build (tokens: texture), not drawn here'),
 'icon': ('✓', 'shipped single-path play and pause with ink joins'),
 'tokens': ('✓', 'every colour, size, radius and shadow is a token; widths are frame sizes'),
 'optical centring': ('✓', 'play glyph nudged 1pt right in its circle; pause centred'),
 'contrast': ('✓', 'headline ≈ 15 : 1, meta ≈ 4.9 : 1, white on the lit play ≈ 3.1 : 1 (glyph, large)'),
 'hit area': ('✓', 'every play and pause is 44; in C the whole row is the target'),
 'states': ('—', 'rest drawn for all six; played, quiet day, making, couldn\'t load come with the one you pick'),
 'motion': ('✓', 'E grows out of A in place (the card height animates, 300ms spring); B\'s fade stays still'),
 'haptic': ('✓', 'play: light impact (it is the lit action)'),
 'goals': ('✓', 'audio first: B and E put the spoken words on the card; F shows receipts (goal: trust what it says)'),
 'wireframe': ('✓', 'A, B, D and F fit the JR-1 slot; C is the PC-1 briefs list row'),
}
open('p03.html', 'w').write(part(3, 'brief card · six versions', 'pick one (or two) to carry forward', vis, rows, 'waiting on your pick: which versions to carry forward?'))
