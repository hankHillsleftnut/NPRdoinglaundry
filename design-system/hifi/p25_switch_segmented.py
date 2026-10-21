# Part 25 · switch and segmented: the two controls that change a setting or a view at once.
from review import *
def tx(s, size, color, w='font-weight-medium', fam='font-label'):
    return f'<div style="font-family:{V(fam)};font-size:{V(size)};font-weight:{V(w)};line-height:{V("leading-tight")};letter-spacing:{V("tracking-label")};color:{C(color)};white-space:nowrap">{s}</div>'
SUNK = f'inset 0 1px 2px {C("depth-shadow-sunken")}, inset 0 0 0 0.5px {C("depth-stroke-outer")}'
THUMB = f'0 2px 5px {C("shadow-thumb-1")}, 0 1px 1px {C("shadow-thumb-2")}, inset 0 -1px 0 {C("depth-stroke-outer")}'
def switch(state):
    on = state in ('on', 'on-pending')
    track_bg = C('ink-default') if on else C('surface-track')
    shadow = f'inset 0 1px 1px {C("shadow-ink-action-1")}' if on else SUNK
    w = 33 if state == 'pressed' else 27
    ring = ''
    if state.endswith('pending'):
        ring = (f'<div layer-name="pending ring" style="width:12px;height:12px;border-radius:{V("radius-control")};'
                f'box-shadow:inset 0 0 0 2px {C("border-strong")};border-top-color:transparent"></div>')
    thumb = (f'<div layer-name="thumb" style="width:{w}px;height:27px;border-radius:{V("radius-control")};background:{C("surface-thumb")};box-shadow:{THUMB};'
             f'display:flex;align-items:center;justify-content:center">{ring}</div>')
    op = 'opacity:var(--opacity-disabled);' if state == 'disabled' else ''
    return (f'<div layer-name="c:switch/default/{state}" style="width:51px;height:31px;flex-shrink:0;padding:{V("spacing-size-border-ring")};border-radius:{V("radius-control")};'
            f'background:{track_bg};box-shadow:{shadow};display:flex;justify-content:{"flex-end" if on else "flex-start"};{op}">{thumb}</div>')
def seg(opts, sel, state='rest'):
    cells = ''
    for o in opts:
        chosen = o == sel
        style = (f'background:{C("background-raised")};box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, inset 0 0 0 1px {C("depth-stroke-inner")}, 0 0 0 0.5px {C("depth-stroke-outer")}, '
                 f'0 1px 1.5px {C("depth-shadow-contact")}, 0 2px 4px -1px {C("depth-shadow-cast")};') if chosen else ''
        col = 'text-primary' if chosen else 'text-label'
        cells += (f'<div layer-name="segment · {o}" style="flex:1;height:32px;border-radius:{V("radius-control")};display:flex;align-items:center;justify-content:center;{style}">'
                  + tx(o, 'text-md', col) + '</div>')
    op = 'opacity:var(--opacity-disabled);' if state == 'disabled' else ''
    return (f'<div layer-name="c:segmented/{len(opts)}/{state}" style="width:326px;height:{V("spacing-size-search-field")};padding:{V("spacing-size-border-ring")};border-radius:{V("radius-control")};'
            f'background:{C("surface-control")};box-shadow:{SUNK};display:flex;{op}">' + cells + '</div>')
def col(*xs, gap='spacing-2'): return f'<div style="display:flex;flex-direction:column;gap:{V(gap)}">' + ''.join(xs) + '</div>'
def cap(s): return label(s)
def slot(el, c): return col(f'<div style="height:44px;display:flex;align-items:center">{el}</div>', cap(c), gap='spacing-1')
def row(*xs): return f'<div style="display:flex;gap:{V("spacing-6")};align-items:flex-start">' + ''.join(xs) + '</div>'
head = lambda t, s: col(f'<div style="font-family:{V("font-label")};font-size:{V("text-md")};font-weight:{V("font-weight-medium")};line-height:{V("leading-snug")};color:{C("text-primary")}">{t}</div>', label(s), gap='spacing-1')
sw_col = col(head('switch', 'sunken track, raised thumb · on is ink, not blue'),
             row(slot(switch('off'), 'off'), slot(switch('on'), 'on'), slot(switch('pressed'), 'held: thumb stretches'), slot(switch('disabled'), 'disabled')), gap='spacing-4')
seg_col = col(head('segmented', 'sunken track, the chosen one raised · no colour'),
              col(slot(seg(['week', 'month', 'year'], 'week'), 'three · week chosen'), slot(seg(['transcript', 'chapters'], 'chapters'), 'two · chapters chosen'),
                  slot(seg(['week', 'month', 'year'], 'month', 'disabled'), 'disabled (the reason is said nearby)'), gap='spacing-3'), gap='spacing-4')
vis = f'<div layer-name="columns" style="display:flex;gap:{V("spacing-16")};flex-wrap:wrap;row-gap:{V("spacing-8")}">' + sw_col + seg_col + '</div>'
rows = {
 'purpose': ('✓', 'switch: turn one setting on or off at once (no save). segmented: pick one of two to five views at once'),
 'colour': ('✓', 'switch on = ink.default track (your blue rule: selection is shown by position and ink, never tinted blue; switch.md\'s sky "on" is replaced); off = surface.track. segmented: chosen label text.primary, others text.label; no colour for the chosen one'),
 'type': ('✓', 'segment labels Geist 14 medium, lowercase, tracking.label (screen rule 4 replaces the spec\'s mono 12)'),
 'space': ('✓', 'switch 51 × 31, 2 padding, thumb 27 (held: 33); segmented 36 tall, 2 padding (the spec’s 3 has no token; 2 matches the switch), thumb 32 tall, equal widths, 326 (the reading width)'),
 'shape': ('✓', 'all true pills (radius.control); concentric: track 15.5 − 2 = thumb 13.5 (switch), 18 − 2 = 16 (segmented)'),
 'depth': ('✓', 'tracks sunken −1 (inner shade + hairline); thumbs raised 2 (switch: thumb shadow pair; segmented: double stroke, contact + cast); the on track is ink with a soft inner shade so it still reads as a channel'),
 'texture': ('—', 'none'),
 'icon': ('—', 'none'),
 'tokens': ('✓', 'surface.track/control/thumb, ink.default, background.raised, depth.shadow.sunken/contact/cast, depth.stroke.*, shadow.thumb.*, shadow.inkAction, opacity.disabled, size.searchField (36); frame sizes raw; token-check 0'),
 'optical centring': ('✓', 'segment labels sit on the x-height centre of the 32 thumb; the switch thumb centres on the track\'s cap'),
 'contrast': ('✓', 'switch: thumb on ink ≈ 18 : 1, track off vs on is obvious without colour (position + value); Increase Contrast adds the system I / O; segment label.primary on raised ≈ 17 : 1, label on control ≈ 4.6 : 1'),
 'hit area': ('✓', 'switch: the whole row (settings), at least 44 × 51 alone; segments at least 44 tall each (the frame grows, the visual stays 36)'),
 'states': ('✓', 'switch: off, on, held (stretch), disabled; no pending state (your call: it did not make sense): the switch moves at once, and if saving fails it snaps back with the subline saying why. segmented: rest, chosen, disabled; pressed dims the touched label. Focus: the system\'s ring, not drawn'),
 'motion': ('✓', 'switch thumb spring 0.3 / 0.75, track crossfades 200ms; segmented thumb slides on 0.3 / 0.85, labels crossfade; Reduce Motion: instant'),
 'haptic': ('✓', 'haptic.select on change (both); haptic.error when a switch snaps back'),
 'goals': ('✓', 'settings say what each thing does and apply at once (settings rule 1); nothing competes with the one lit action'),
 'wireframe': ('✓', 'the mid-fi\'s grey switch and lifted segment, made exact'),
}
open('p25.html', 'w').write(part(25, 'switch · segmented', 'change a setting or a view, at once', vis, rows,
     'ready for your review. change from the spec: the switch\'s "on" is ink, not sky blue (your blue rule).'))
