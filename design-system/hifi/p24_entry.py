# Part 24 · entry parts (JR-4): your words, the meta line, what retro took (with not right), delete and its dialog.
import json
from review import *
I = json.load(open('../icons/outlined-20.json'))
def glyph(n, px, c): return f'<svg width="{px}" height="{px}" viewBox="0 0 24 24" style="flex-shrink:0"><path fill="{c}" fill-rule="evenodd" d="{I[n]}"/></svg>'
def tx(s, size, color, fam='font-text', w='font-weight-regular', extra=''):
    return f'<div style="font-family:{V(fam)};font-size:{V(size)};font-weight:{V(w)};line-height:{V("leading-snug")};color:{C(color)};{extra}">{s}</div>'
def col(*xs, gap='spacing-2', extra=''): return f'<div style="display:flex;flex-direction:column;gap:{V(gap)};{extra}">' + ''.join(xs) + '</div>'
def row(*xs, gap='spacing-2', extra=''): return f'<div style="display:flex;align-items:center;gap:{V(gap)};{extra}">' + ''.join(xs) + '</div>'
def words(s):
    return (f'<div layer-name="c:entry/words/rest" style="font-family:{V("font-display-inky")};font-size:{V("text-xl")};font-weight:{V("font-weight-ink-card")};'
            f'line-height:{V("leading-snug")};letter-spacing:{V("tracking-card")};text-wrap:balance;color:{C("text-primary")}">{s}</div>')
def meta(parts, state=None):
    base = tx(' · '.join(parts), 'text-sm', 'text-label', fam='font-label')
    if state == 'read': return row(base, glyph('check', 12, C('icon-muted')), gap='spacing-1')
    if state == 'rereading': return row(base, tx('· retro is reading it again', 'text-sm', 'text-label', fam='font-label'), gap='spacing-1')
    if state == 'failed': return row(glyph('retry', 12, C('status-danger-text')), tx("didn't send · tap to retry", 'text-sm', 'status-danger-text', fam='font-label'), gap='spacing-1')
    return base
def link():
    return (f'<div layer-name="c:link/conversation/rest" style="min-height:44px;display:flex;align-items:center;gap:{V("spacing-1")}">'
            + tx('show it in the conversation', 'text-md', 'text-link') + glyph('chevron-right', 14, C('text-link')) + '</div>')
def pill_nr(state='rest'):
    bg = C('surface-wash-pressed') if state == 'pressed' else C('surface-wash')
    return (f'<div layer-name="c:pill/neutral/{state}" style="height:32px;border-radius:{V("radius-control")};background:{bg};display:flex;align-items:center;gap:{V("spacing-1")};'
            f'padding:0 {V("spacing-3")} 0 {V("spacing-2")};flex-shrink:0">' + glyph('correct', 16, C('icon-default'))
            + tx('not right', 'text-md', 'text-primary', fam='font-label', w='font-weight-medium', extra='white-space:nowrap') + '</div>')
def took(claim, state='rest'):
    if state == 'noted':
        right = row(glyph('check', 14, C('icon-muted')), tx('noted', 'text-md', 'text-label', fam='font-label'), gap='spacing-1', extra='flex-shrink:0;min-height:44px')
        c = tx(claim, 'text-md', 'text-tertiary', extra='flex:1;text-decoration:line-through')
    else:
        right = f'<div style="height:44px;display:flex;align-items:center;flex-shrink:0">{pill_nr()}</div>'
        c = tx(claim, 'text-md', 'text-primary', extra=f'flex:1;padding-top:{V("spacing-1")};text-wrap:balance')
    # founder 20 oct ("a bit ugly, fix that"): a live claim is a light raised card so the wash pill stands off it; a noted one goes flat
    look = (f'background:{C("background-raised")};box-shadow:0 0 0 0.5px {C("depth-stroke-outer")}, 0 1px 2px {C("depth-shadow-contact")};'
            f'padding:{V("spacing-3")} {V("spacing-3")} {V("spacing-3")} {V("spacing-4")};align-items:flex-start' if state != 'noted' else
            f'box-shadow:inset 0 0 0 0.5px {C("border-strong")};padding:{V("spacing-1")} {V("spacing-3")} {V("spacing-1")} {V("spacing-4")};align-items:center')
    return (f'<div layer-name="c:took-row/claim/{state}" style="border-radius:{V("radius-default")};{look};'
            f'display:flex;gap:{V("spacing-3")}">' + c + right + '</div>')
def took_list(rows):
    return col(tx('what i took from this', 'text-sm', 'text-label', fam='font-label', w='font-weight-medium'), *rows, gap='spacing-2')
def delete_row():
    return (f'<div layer-name="c:row/destructive/rest" style="min-height:44px;display:flex;align-items:center;justify-content:center;gap:{V("spacing-1")}">'
            + tx('delete entry', 'text-md', 'status-danger-text', fam='font-label', w='font-weight-medium') + '</div>')
def dialog(w=300, bare=False):
    btn = (f'<div layer-name="c:button/destructive-compact/rest" style="height:48px;border-radius:{V("radius-control")};background:linear-gradient(180deg, {C("glow-danger-gradient-top")}, {C("glow-danger-gradient-bottom")});'
           f'box-shadow:inset 0 1px 0 {C("glow-danger-rim")}, inset 0 0 0 0.5px {C("glow-danger-edge")}, 0 1px 2px {C("shadow-primary-action-2")}, 0 6px 14px -6px {C("depth-tint-danger")};'
           f'display:flex;align-items:center;justify-content:center">' + tx('delete it', 'text-base', 'glow-danger-foreground', fam='font-label', w='font-weight-medium', extra=f'letter-spacing:{V("tracking-label")};text-shadow:0 1px 0 {C("shadow-on-accent-text-1")}') + '</div>')
    keep = f'<div layer-name="c:button/link/rest" style="height:44px;display:flex;align-items:center;justify-content:center">' + tx('keep it', 'text-md', 'text-secondary', fam='font-label', w='font-weight-medium') + '</div>'
    card = (f'<div layer-name="c:dialog/destructive/rest" style="width:{w}px;border-radius:{V("radius-field")};background:{C("background-raised")};padding:{V("spacing-6")} {V("spacing-6")} {V("spacing-4")};'
            f'box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, inset 0 0 0 1px {C("depth-stroke-inner")}, 0 0 0 0.5px {C("depth-stroke-outer")}, 0 4px 12px {C("shadow-overlay-2")}, 0 24px 48px -12px {C("shadow-overlay-1")};'
            f'display:flex;flex-direction:column;gap:{V("spacing-4")}">'
            + col(f'<div style="font-family:{V("font-display")};font-size:{V("text-xl")};letter-spacing:{V("tracking-card")};line-height:{V("leading-snug")};color:{C("text-primary")}">delete this entry?</div>',
                  tx("this removes it and what retro took from it. it can't be undone.", 'text-md', 'text-secondary'), gap='spacing-2')
            + col(btn, keep, gap='spacing-1') + '</div>')
    if bare: return card
    return (f'<div layer-name="scrim (the page behind, dimmed)" style="width:348px;padding:{V("spacing-6")};border-radius:{V("radius-panel")};background:{C("background-scrim")};display:flex;justify-content:center">{card}</div>')
W = 'width:342px'
rest = col(words("i think it's the 9am standup. i dread it."), meta(['today', '9:12', 'written', 'read'], 'read'), link(), gap='spacing-2', extra=W)
states = col(col(words('slept badly, long day of meetings'), meta(['yesterday', '22:40', 'written'], 'rereading'), gap='spacing-2'),
             col(words('the fundraise article you shared'), meta([], 'failed'), gap='spacing-2'), gap='spacing-6', extra=W)
tooks = col(took_list([took('the monday standup is hard for you'), took('you feel dread before 9am meetings', 'noted')]), delete_row(), gap='spacing-6', extra=W)
vis = (tile(rest, '1× · your words (inky, 22) · the meta line, read ✓ · the link back to the conversation')
       + tile(states, '1× · re-reading after an edit · failed to send (one tap retries)')
       + tile(tooks, '1× · what retro took: each claim with not right (a neutral pill) · a corrected one dims to "noted" · delete in the bottom zone')
       + tile(dialog(), '1× · delete asks once: the one destructive (lit danger) in a dialog, "keep it" as the quiet way out'))
rows = {
 'purpose': ('✓', 'read back one thing you said, see exactly what retro took from it, correct a claim where you see it (O-10), or remove it all'),
 'colour': ('✓', 'words text.primary; meta text.label; link text.link (a link in text: allowed blue); claims on surface.wash; noted text.tertiary + struck; delete status.dangerText; the dialog\'s button the danger glow, the only lit thing'),
 'type': ('✓', 'words Exposure (the inky face) 22, ink −10 weight, tracking.card (type.md card headline); meta Geist 400 12; claims SF Pro 14; dialog title Hedvig 22; buttons Geist medium (your call)'),
 'space': ('✓', 'words → meta 8, meta → link 0 (link carries its own 44); list label → rows 8, rows 8 apart, row padding 4 / 8 / 4 / 16 so the 32 pill sits 6 from the row edge; delete 24 below; dialog padding 24 / 24 / 16, 16 between blocks'),
 'shape': ('✓', 'claim rows radius.default; pill radius.control (inner 16 in a row with 6 clearance: concentric with the row\'s 10 + padding, close enough at this size); dialog radius.field 12 (your call: sharper)'),
 'depth': ('✓', 'words on the page; claims wash 0.5 (they inform and offer a fix); the dialog overlay 4 (double stroke, ambient + cast); its button lit 5 in danger; the page behind dims under background.scrim'),
 'texture': ('—', 'no gradient large enough to band: the dialog card is flat raised paper; the 48 button is under the 60 grain threshold'),
 'icon': ('✓', 'check (read, noted), retry (failed), correct (not right), chevron-right (the link): all from the inked set at 20pt'),
 'tokens': ('✓', 'font.displayInky, font.weight.inkCard, tracking.card, text.xl/md/sm, surface.wash(.pressed), status.dangerText, glow.danger.*, depth.tint.danger, shadow.overlay.*, depth.stroke.*, background.raised/scrim, radius.card/default/control/panel; token-check 0'),
 'optical centring': ('✓', 'the read ✓ sits on the meta\'s x-height; the struck line passes through the x-height, not the baseline'),
 'contrast': ('✓', 'words ≈ 17 : 1; claim on wash ≈ 15 : 1; noted (tertiary) ≈ 4.6 : 1 with "noted" in words beside it; white on the danger glow ≥ 4.5 : 1 at its bottom stop'),
 'hit area': ('✓', 'link 44 tall; not right pill in a 44 frame; delete row 44; dialog buttons 48 and 44'),
 'states': ('✓', 'rest, read, re-reading, failed (retry), claim corrected → noted, delete → dialog; editing turns the words into a text field with save (built with the composer, part of the fork\'s set); offline: edits and deletes queue, marked "waiting to send"'),
 'motion': ('✓', 'not right → noted crossfades 200ms and the line strikes left to right over 240ms; the dialog scales from 0.96 with the overlay spring, the page dims 200ms; Reduce Motion: fades only'),
 'haptic': ('✓', 'not right: haptic.success when it\'s noted; delete it: haptic.warning on touch down (it can\'t be undone)'),
 'goals': ('✓', 'nothing is lost and nothing is hidden: you see what was taken and fix it in place; delete reaches the brain too (K7)'),
 'wireframe': ('✓', 'JR-4: back · edit on top, your words large, date · kind · state, "what i took" with not right, delete at the bottom behind a dialog'),
}
open('p24.html', 'w').write(part(24, 'entry · words · what retro took · delete', 'read back one thing you said; correct or remove it', vis, rows,
     'ready for your review. one question: should a corrected claim stay in the list as "noted" (as drawn) or disappear?'))
