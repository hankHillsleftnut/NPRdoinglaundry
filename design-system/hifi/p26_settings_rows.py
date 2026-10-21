# Part 26 · settings rows: the 56 row (part 22) with each kind of trailing control.
import json
from review import *
I = json.load(open('../icons/outlined-20.json'))
def glyph(n, px, c): return f'<svg width="{px}" height="{px}" viewBox="0 0 24 24" style="flex-shrink:0"><path fill="{c}" fill-rule="evenodd" d="{I[n]}"/></svg>'
def txt(s, size, color, w='font-weight-regular', fam='font-text'):
    return f'<div style="font-family:{V(fam)};font-size:{V(size)};font-weight:{V(w)};line-height:{V("leading-snug")};' + (f'letter-spacing:{V("tracking-card")};' if size == 'text-body' else '') + f'color:{C(color)};white-space:nowrap">{s}</div>'
def words(title, sub, tcol='text-primary'):
    return (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-size-border-ring")};flex:1;min-width:0">' + txt(title, 'text-body', tcol)
            + (txt(sub, 'text-md', 'text-secondary') if sub else '') + '</div>')
def well(n): return (f'<div layer-name="icon well 32" style="width:32px;height:32px;border-radius:{V("radius-default")};background:{C("surface-wash")};'
                     f'display:flex;align-items:center;justify-content:center;flex-shrink:0">{glyph(n, 20, C("icon-default"))}</div>')
def row(kind, inner, state='rest'):
    return (f'<div layer-name="c:settings-row/{kind}/{state}" style="width:390px;min-height:{V("spacing-size-row-default")};padding:{V("spacing-4")} {V("spacing-screen-margin")};'
            f'display:flex;align-items:center;gap:{V("spacing-3")}">' + inner + '</div>')
def hairline(icon=False):
    pre = (f'<div style="width:{V("spacing-size-source-icon")};flex-shrink:0"></div><div style="width:{V("spacing-3")};flex-shrink:0"></div>') if icon else ''
    return (f'<div layer-name="c:hairline/inset{"-icon" if icon else ""}/rest" style="width:390px;padding-left:{V("spacing-screen-margin")};display:flex">{pre}'
            f'<div style="height:{V("spacing-size-border-hairline")};flex:1;background:{C("border-strong")}"></div></div>')
def stack(*xs): return '<div style="display:flex;flex-direction:column">' + ''.join(xs) + '</div>'
SUNK = f'inset 0 1px 2px {C("depth-shadow-sunken")}, inset 0 0 0 0.5px {C("depth-stroke-outer")}'
THUMB = f'0 2px 5px {C("shadow-thumb-1")}, 0 1px 1px {C("shadow-thumb-2")}, inset 0 -1px 0 {C("depth-stroke-outer")}'
def switch(on):
    bg, sh = (C('ink-default'), f'inset 0 1px 1px {C("shadow-ink-action-1")}') if on else (C('surface-track'), SUNK)
    return (f'<div layer-name="c:switch/default/{"on" if on else "off"}" style="width:51px;height:31px;flex-shrink:0;padding:{V("spacing-size-border-ring")};border-radius:{V("radius-control")};'
            f'background:{bg};box-shadow:{sh};display:flex;justify-content:{"flex-end" if on else "flex-start"}"><div style="width:27px;height:27px;border-radius:{V("radius-control")};background:{C("surface-thumb")};box-shadow:{THUMB}"></div></div>')
def tick(on): return f'<div style="width:20px;display:flex;justify-content:center;flex-shrink:0">' + (glyph('check', 20, C('ink-default')) if on else '') + '</div>'
def status(word, tok):
    return (f'<div style="display:flex;align-items:center;gap:{V("spacing-2")};flex-shrink:0"><div style="width:{V("spacing-size-step-dot")};height:{V("spacing-size-step-dot")};border-radius:{V("radius-control")};background:{C(tok)}"></div>'
            + txt(word, 'text-md', 'text-secondary') + '</div>')
def raised_pill(label, icon):
    return (f'<div layer-name="c:pill/raised/rest" style="height:32px;border-radius:{V("radius-control")};background:{C("surface-secondary-action")};'
            f'box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, inset 0 0 0 1px {C("depth-stroke-inner")}, 0 0 0 0.5px {C("depth-stroke-outer")}, 0 1px 1.5px {C("depth-shadow-contact")}, 0 4px 6px -2px {C("depth-shadow-cast")};'
            f'display:flex;align-items:center;gap:{V("spacing-1")};padding:0 {V("spacing-3")} 0 {V("spacing-2")};flex-shrink:0">' + glyph(icon, 16, C('icon-default'))
            + txt(label, 'text-md', 'text-primary', w='font-weight-medium', fam='font-label') + '</div>')
switches = stack(row('switch', words('autoplay the next episode', 'when the current one ends') + switch(True)), hairline(),
                 row('switch', words('notify me when my brief is ready', 'one notification a day, at 8:30') + switch(False)))
choice = stack(row('choice', words('warm', 'unhurried, close') + tick(True), 'chosen'), hairline(),
               row('choice', words('clear', 'brisk, plain') + tick(False)), hairline(),
               row('choice', words('quiet', 'soft, slower') + tick(False)))
other = stack(row('leaves-app', words('privacy policy', 'opens in safari') + glyph('external', 16, C('icon-muted'))), hairline(),
              row('value', words('export your journal', 'everything you wrote, as text') + glyph('chevron-right', 16, C('icon-muted'))))
def dwell(): return (f'<div layer-name="icon well 32 · danger" style="width:32px;height:32px;border-radius:{V("radius-default")};background:{C("status-danger-subtle")};'
                     f'display:flex;align-items:center;justify-content:center;flex-shrink:0">{glyph("alert", 20, C("status-danger-text"))}</div>')
danger = stack(row('danger', dwell() + words('delete my account', 'removes everything, after a confirmation', 'status-danger-text')))  # founder picked A (red well), 20 Oct
sources = stack(row('source', well('calendar') + words('calendar', 'so your brief knows your day') + status('connected', 'source-connected')), hairline(True),
                row('source', well('mic') + words('voice notes', 'in your own words') + raised_pill('connect', 'add')), hairline(True),
                row('source', well('podcasts') + words('podcasts', 'what you listen to') + status('reconnect', 'source-problem'), 'problem'), hairline(True),
                row('source', well('brief') + words('health', 'how you slept, how you moved') + status('syncing', 'source-syncing'), 'syncing'))
vis = (tile(switches, '1× · switch rows: the title says what, the subline what on means; the switch applies at once')
       + tile(choice, '1× · choice rows: one ink tick marks the chosen; no colour, no radio circles')
       + tile(other, '1× · leaves the app: ↗ external (only for links out) · inside the app: › chevron')
       + tile(danger, '1× · danger: alone, last, in danger text; opens the dialog (part 24)')
       + tile(sources, '1× · sources: purpose as the subline; status in words with a dot (never colour alone); connect is a raised pill (rule 15)'))
rows = {
 'purpose': ('✓', 'every setting says what it does and shows its control in the same place, so the page reads top to bottom without hunting'),
 'colour': ('✓', 'switch on in ink; the tick ink.default; status dots source.connected / problem / syncing always with the word; danger status.dangerText; no blue anywhere on the page'),
 'type': ('✓', 'titles SF Pro 17, sublines 14 text.secondary; status words 14 text.secondary; connect Geist 14 medium'),
 'space': ('✓', 'the part 22 row: min 56, padding 16 / 24, 12 between parts; trailing controls centre on the pair'),
 'shape': ('✓', 'rows sit on the page; wells radius 10; status dots 6 round; switch and pill are true pills'),
 'depth': ('✓', 'page level 0; the switch thumb and the connect pill are the only raised things, because they are what your finger grabs'),
 'texture': ('—', 'none'),
 'icon': ('✓', 'external only for links that leave the app, chevron-right for places inside (settings rule 2); source wells use the set (the health well uses brief as a stand-in until a health glyph is drawn, flagged)'),
 'tokens': ('✓', 'size.row.default, size.sourceIcon, size.stepDot, source.*, status.dangerText, ink.default, surface.track/thumb/secondaryAction, depth.*, border.strong; token-check 0'),
 'optical centring': ('✓', 'the tick sits in a 20 slot so the titles in a choice group align whether or not they are chosen'),
 'contrast': ('✓', 'all text ≥ 6 : 1; status never colour alone; Increase Contrast: hairlines 1pt border.control'),
 'hit area': ('✓', 'the whole row is the target for switch, choice, link and danger rows; connect has its own 44'),
 'states': ('✓', 'switch on / off, choice chosen / not, source connected / connect / problem / syncing; pressed rows take surface.subtle (part 22); disabled rows say why in the subline'),
 'motion': ('✓', 'switch and tick change at once with haptic.select; source status crossfades 200ms'),
 'haptic': ('✓', 'haptic.select on a switch or choice; haptic.warning only inside the delete dialog'),
 'goals': ('✓', 'settings in plain words, applied at once, nothing for developers (settings rules 1–4); sources say why they are there, not what they read'),
 'wireframe': ('✓', 'the mid-fi Settings pages (ST-1 to ST-9): srow, sw, tick, the danger row last'),
}
open('p26.html', 'w').write(part(26, 'settings rows', 'each kind of setting, with its control in the same place', vis, rows,
     'ready for your review. one gap flagged: the set has no health glyph yet (brief stands in on the health source row).'))
