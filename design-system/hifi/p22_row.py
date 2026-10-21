# Part 22 · the 56 row and its hairline: the list unit under settings, the drawer and sources.
import json
from review import *
I = json.load(open('../icons/outlined-20.json'))
def glyph(n, px, c): return f'<svg width="{px}" height="{px}" viewBox="0 0 24 24" style="flex-shrink:0"><path fill="{c}" fill-rule="evenodd" d="{I[n]}"/></svg>'
def txt(s, size, color, w='font-weight-regular', fam='font-text'):
    return f'<div style="font-family:{V(fam)};font-size:{V(size)};font-weight:{V(w)};line-height:{V("leading-snug")};color:{C(color)}">{s}</div>'
def row(variant, title, sub=None, value=None, lead=None, state='rest'):
    dis = state == 'disabled'
    tcol, scol = ('text-tertiary', 'text-tertiary') if dis else ('text-primary', 'text-secondary')
    bg = f'background:{C("surface-subtle")};' if state == 'pressed' else ''
    ring = f'box-shadow:inset 0 0 0 2px {C("border-focus")};' if state == 'focused' else ''
    lead_el = (f'<div layer-name="icon well 32" style="width:32px;height:32px;border-radius:{V("radius-default")};background:{C("surface-wash")};'
               f'display:flex;align-items:center;justify-content:center;flex-shrink:0">{glyph(lead, 20, C("icon-default"))}</div>') if lead else ''
    words = (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-size-border-ring")};flex:1;min-width:0">' + txt(title, 'text-body', tcol)
             + (txt(sub, 'text-md', scol) if sub else '') + '</div>')
    trail = (txt(value, 'text-md', 'text-secondary') if value else '') + ('' if value else glyph('chevron-right', 16, C('icon-muted')))
    return (f'<div layer-name="c:row/{variant}/{state}" style="width:390px;min-height:{V("spacing-size-row-default")};padding:{V("spacing-4")} {V("spacing-screen-margin")};'
            f'display:flex;align-items:center;gap:{V("spacing-3")};{bg}{ring}">' + lead_el + words
            + f'<div style="display:flex;align-items:center;gap:{V("spacing-1")};flex-shrink:0">{trail}</div></div>')
def hairline():  # 0.5 border.subtle, inset to the text (starts at the screen margin), between rows only
    return (f'<div layer-name="c:hairline/inset/rest" style="width:390px;padding-left:{V("spacing-screen-margin")};display:flex">'
            f'<div style="height:{V("spacing-size-border-hairline")};flex:1;background:{C("border-subtle")}"></div></div>')
def hairline_lead():  # with a leading icon, the inset moves to the text: margin + well + gap
    return (f'<div layer-name="c:hairline/inset-icon/rest" style="width:390px;padding-left:{V("spacing-screen-margin")};display:flex">'
            f'<div style="width:{V("spacing-size-source-icon")};flex-shrink:0"></div><div style="width:{V("spacing-3")};flex-shrink:0"></div>'
            f'<div style="height:{V("spacing-size-border-hairline")};flex:1;background:{C("border-subtle")}"></div></div>')
def stack(*xs): return '<div style="display:flex;flex-direction:column">' + ''.join(xs) + '</div>'
group = stack(row('title', 'notifications'), hairline(), row('subline-value', 'voice', 'how retro sounds when it reads to you', value='warm'), hairline(),
              row('subline', 'autoplay the next episode', 'when the current one ends'))
sources = stack(row('icon', 'calendar', 'so your brief knows what today holds', lead='calendar'), hairline_lead(),
                row('icon', 'voice notes', 'what you say to retro, in your own words', lead='mic'))
states = stack(row('title', 'notifications', state='pressed'), hairline(), row('title', 'notifications', state='focused'), hairline(),
               row('subline', 'autoplay the next episode', 'needs a connection', state='disabled'))
vis = (tile(group, '1× · a group: title only · subline + value · subline · hairlines between rows, inset to the text, none after the last')
       + tile(sources, '1× · with a leading icon well (32, radius 10, wash) · the hairline insets past the well to the text')
       + tile(states, '1× · pressed (surface.subtle at once) · focused (2pt inset ring) · disabled (tertiary, the subline says why)'))
rows = {
 'purpose': ('✓', 'one row = one thing you can open or change; the hairline only separates, it never frames'),
 'colour': ('✓', 'title text.primary, subline text.secondary, value text.secondary, chevron icon.muted; pressed surface.subtle; hairline border.subtle'),
 'type': ('✓', 'title SF Pro Text 17 (text.body), subline 14 (text.md), leading.snug, 2 between them; lowercase titles that say what it does (settings-row rule 1)'),
 'space': ('✓', 'min 56 (size.row.default), padding 16 / 24 (screen margin), 12 between parts; the trailing control centres on the title (one line) or the pair (two)'),
 'shape': ('✓', 'no container: rows sit on the page; the icon well is radius 10 at 32, so its corners echo the card radius family'),
 'depth': ('✓', 'page level 0; groups separated by space (32), never boxed (surfaces rule 2)'),
 'texture': ('—', 'none'),
 'icon': ('✓', 'new chevron-right added to the inked set (the set had none); 16 in icon.muted, so it points without competing; ↗ external only for links that leave the app'),
 'tokens': ('✓', 'size.row.default, screen-margin, spacing 1/3/4, size.border.hairline, size.sourceIcon, radius.default, border.subtle, surface.subtle, border.focus, text.*; token-check 0'),
 'optical centring': ('✓', 'the chevron is centred by its mass (the inked tip carries more weight than the open ends), not its box'),
 'contrast': ('✓', 'title ≈ 16 : 1, subline ≈ 6 : 1; hairline is decorative (exempt) and never the only separation; Increase Contrast makes it 1pt border.control'),
 'hit area': ('✓', 'the whole row, full width, at least 56 tall'),
 'states': ('✓', 'rest, pressed, focused, disabled drawn; error turns the subline status.dangerText with the fix; loading shows a 40-wide skeleton in the trailing slot; empty groups are not shown'),
 'motion': ('✓', 'pressed shows at once, fades back over 240ms; Reduce Motion: no fade'),
 'haptic': ('—', 'none (navigation)'),
 'goals': ('✓', 'settings say what each thing does, in your words (rule 1); sources show their purpose, not their permission'),
 'wireframe': ('✓', 'matches the mid-fi\'s srow: title, subline, trailing control, 56 tall, hairline'),
}
open('p22.html', 'w').write(part(22, 'row 56 · hairline', 'the list unit: one thing to open or change', vis, rows,
     'ready for your review. new icon in the set: chevron-right (it was missing).'))
