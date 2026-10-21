from review import *
G = '<rect x="3.25" y="5.25" width="17.5" height="13.5" rx="3"/><path d="M9.25 5.25v13.5"/>'
def button(scale, state):
    s = scale
    bg = {'rest': 'surface-wash', 'pressed': 'surface-wash-pressed', 'focused': 'surface-wash'}[state]
    k = 0.94 if state == 'pressed' else 1
    ring = f'box-shadow:0 0 0 {2*s}px {C("background-canvas")}, 0 0 0 {4*s}px {C("border-focus")};' if state == 'focused' else ''
    glyph = f'<svg width="{20*s}" height="{20*s}" viewBox="0 0 24 24" fill="none" stroke="{C("icon-default")}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">{G}</svg>'
    circle = (f'<div layer-name="c:icon-button/wash/{state}" style="width:{36*s}px;height:{36*s}px;border-radius:{V("radius-control")};background:{C(bg)};{ring}'
              f'display:flex;align-items:center;justify-content:center;transform:scale({k})">{glyph}</div>')
    hit = (f'<div layer-name="hit area 44" style="width:{44*s}px;height:{44*s}px;display:flex;align-items:center;justify-content:center;'
           f'outline:1px dashed {C("text-link")};outline-offset:-1px">{circle}</div>') if s > 1 else f'<div style="width:44px;height:44px;display:flex;align-items:center;justify-content:center">{circle}</div>'
    return hit
vis = (''.join(tile(button(4, st), f'4× · {st}' + (' · wash' if st == 'rest' else ' · wash pressed, 0.94' if st == 'pressed' else ' · 2pt focus ring, 2pt off the edge')) for st in ['rest', 'pressed', 'focused'])
       + tile(f'<div style="display:flex;gap:{V("spacing-4")};align-items:center">' + button(1, 'rest') + button(1, 'pressed') + button(1, 'focused') + '</div>', '1× · rest · pressed · focused · dashed blue at 4× is the 44 tap area'))
rows = {
 'purpose': ('✓', 'the one way into all journals from Journal; a wash circle says "a quiet tool", not "the next step"'),
 'colour': ('✓', 'surface.wash (warm 6%) at rest, surface.washPressed when held; glyph icon.default'),
 'type': ('—', 'no text; VoiceOver label "all journals"'),
 'space': ('✓', '36 circle, 20 glyph, 8 all round; centred in a 44 tap area'),
 'shape': ('✓', 'a true circle (radius.control); the glyph\'s rx 3 sits inside it without fighting'),
 'depth': ('✓', 'wash (0.5): no stroke, no shadow, because it informs and offers, it doesn\'t lead (surfaces rule 3)'),
 'texture': ('—', 'under 44, no grain'),
 'icon': ('✓', 'drawer at 20 with stroke 2 in its 24 grid (about 1.67pt), so it holds its weight smaller'),
 'tokens': ('✓', 'surface.wash, surface.washPressed, border.focus, background.canvas, radius.control; sizes are frame sizes'),
 'optical centring': ('✓', 'the glyph is symmetric top to bottom, and the divider\'s weight on the left balances the open panel: box centre equals mass centre here'),
 'contrast': ('✓', 'glyph ≈ 14 : 1 on the wash; the wash itself is not a control edge, the glyph carries it'),
 'hit area': ('✓', '44 × 44, padded around the 36 visual'),
 'states': ('✓', 'rest, pressed, focused drawn; disabled never occurs (the drawer always opens); dark in the dark pass'),
 'motion': ('✓', 'press in 80ms to 0.94, out 240ms; opens the drawer on release with the drawer\'s spring'),
 'haptic': ('—', 'none: not a lit action (craft §10)'),
 'goals': ('✓', 'the drawer is Journal\'s index (rule 29); the button stays quiet so the brief card stays the lit thing'),
 'wireframe': ('✓', 'same place as the mid-fi: leading edge of the top bar, 36 visual'),
}
open('p02.html', 'w').write(part(2, 'icon button · wash', 'a quiet tool in the top bar: all journals', vis, rows, 'ready for your review. one question below.'))
