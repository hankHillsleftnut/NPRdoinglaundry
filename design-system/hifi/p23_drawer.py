# Part 23 · drawer parts: the search field and the entry row, on the drawer's grey underlay.
import json
from review import *
I = json.load(open('../icons/outlined-20.json'))
def glyph(n, px, c): return f'<svg width="{px}" height="{px}" viewBox="0 0 24 24" style="flex-shrink:0"><path fill="{c}" fill-rule="evenodd" d="{I[n]}"/></svg>'
def tx(s, size, color, fam='font-text', w='font-weight-regular', extra=''):
    return f'<div style="font-family:{V(fam)};font-size:{V(size)};font-weight:{V(w)};line-height:{V("leading-snug")};' + (f'letter-spacing:{V("tracking-card")};' if size == "text-body" else "") + f'color:{C(color)};{extra}">{s}</div>'
SUNK = f'box-shadow:inset 0 1px 2px {C("depth-shadow-sunken")}, inset 0 0 0 0.5px {C("depth-stroke-outer")}'
def search(state='rest'):
    if state == 'rest':
        inner = glyph('search', 16, C('icon-muted')) + tx('search your journal', 'text-body', 'text-tertiary', extra='flex:1')
    else:
        inner = (glyph('search', 16, C('icon-muted')) + '<div style="display:flex;align-items:center;flex:1">' + tx('standup', 'text-body', 'text-primary')
                 + f'<div layer-name="caret" style="width:{V("spacing-size-border-ring")};height:20px;background:{C("ink-default")};border-radius:{V("radius-small")}"></div></div>'
                 + f'<div layer-name="clear" style="width:20px;height:20px;border-radius:{V("radius-control")};background:{C("surface-wash-pressed")};display:flex;align-items:center;justify-content:center">{glyph("close", 12, C("icon-default"))}</div>')
    field = (f'<div layer-name="c:search-field/journal/{state}" style="height:{V("spacing-size-search-field")};border-radius:{V("radius-control")};background:{C("surface-wash-pressed")};{SUNK};'
             f'display:flex;align-items:center;gap:{V("spacing-2")};padding:0 {V("spacing-3")}">{inner}</div>')
    return f'<div layer-name="tap area 44" style="height:44px;display:flex;flex-direction:column;justify-content:center">{field}</div>'
def day(s): return f'<div layer-name="c:label/day/rest" style="font-family:{V("font-label")};font-size:{V("text-sm")};font-weight:{V("font-weight-medium")};line-height:{V("leading-snug")};letter-spacing:{V("tracking-label")};color:{C("text-label")};padding:0 {V("spacing-3")}">{s}</div>'
def entry(words, meta, state='rest', match=None):
    if match:  # Paper has no rich text: the line is three pieces in a row, the match in blue + medium
        a, b = words.split(match, 1)
        piece = lambda t, m=False: (f'<div style="font-family:{V("font-text")};font-size:{V("text-body")};line-height:{V("leading-snug")};letter-spacing:{V("tracking-card")};white-space:pre;'
                                    + (f'color:{C("accent-text")};font-weight:{V("font-weight-medium")}' if m else f'color:{C("text-primary")};font-weight:{V("font-weight-regular")}') + f'">{t}</div>')
        words_el = '<div style="display:flex;align-items:baseline">' + piece(a) + piece(match, True) + piece(b) + '</div>'
    else:
        words_el = tx(words, 'text-body', 'text-primary', extra='display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;text-wrap:balance')  # balanced: M4, founder yes
    bg = {'here': f'background:{C("background-canvas")};box-shadow:0 0 0 0.5px {C("depth-stroke-outer")}, 0 1px 1.5px {C("depth-shadow-contact")};',
          'pressed': f'background:{C("surface-wash")};'}.get(state, '')
    meta_el = (tx(meta, 'text-sm', 'text-label', fam='font-label') if state != 'unsent' else
               f'<div style="display:flex;align-items:center;gap:{V("spacing-1")}">' + glyph('retry', 14, C('status-danger-text'))
               + tx(meta, 'text-sm', 'status-danger-text', fam='font-label') + '</div>')
    return (f'<div layer-name="c:entry-row/drawer/{state}" style="border-radius:{V("radius-default")};padding:{V("spacing-3")};{bg}display:flex;flex-direction:column;gap:{V("spacing-1")}">'
            + words_el + meta_el + '</div>')
def underlay(*xs):
    return (f'<div layer-name="drawer underlay" style="width:300px;background:{C("surface-control")};border-radius:{V("radius-panel")};padding:{V("spacing-4")};'
            f'display:flex;flex-direction:column;gap:{V("spacing-4")}">' + ''.join(xs) + '</div>')
def group(*xs): return f'<div style="display:flex;flex-direction:column;gap:{V("spacing-1")}">' + ''.join(xs) + '</div>'
listing = underlay(search('rest'),
    group(day('today'), entry("i think it's the 9am standup. i dread it.", '3 messages · retro replied · 9:12', 'here')),
    group(day('yesterday'), entry('slept badly, long day of meetings', '2 messages · 22:40'),
          entry('on the walk home i kept thinking about the offer, and whether i even want it', 'voice note · 1:42'),
          entry('the fundraise article you shared', 'not sent · tap to retry', 'unsent')))
results = underlay(search('typing'),
    group(day('2 matches'), entry('the 9am standup again', 'today · 9:12', match='standup'),
          entry('standup ran long, i said nothing', 'tue 14 oct · 10:05', match='standup', state='pressed')))
vis = (tile(listing, '1× · on the drawer underlay · search at rest · the conversation in view is lifted (canvas + contact) · a voice note wraps to 2 lines · an unsent note retries in one tap')
       + tile(results, '1× · searching: results replace the days; the matched word is blue and medium · a row pressed'))
rows = {
 'purpose': ('✓', 'the drawer is Journal\'s index (rule 29): find any conversation by its words, see which one you\'re in, jump to it'),
 'colour': ('✓', 'underlay surface.control; field surface.washPressed (a wash, so it is always darker than whatever it sits on); words text.primary, meta text.label; the lifted row background.canvas; unsent status.dangerText with words; matched words accent.text (your call: search keywords are blue)'),
 'type': ('✓', 'words SF Pro Text 17 (your own words, two lines then ellipsis); meta Geist 400 12 (type.md: 400 for meta); placeholder text.tertiary 17'),
 'space': ('✓', 'underlay padding 16; field 36 in a 44 tap area, 12 inside, 8 to the glyph; rows padding 12, 4 between words and meta, 4 between rows, 16 between days, day label 12 in so it aligns with row text'),
 'shape': ('✓', 'field is a true pill (radius.control); rows radius.default (10); the underlay\'s radius 16 is the drawer panel\'s, not nested, so no concentric rule applies'),
 'depth': ('✓', 'field sunken −1 (inner shade + 0.5 hairline: it reads sunken even though its fill is lighter than the grey underlay); rows on the page; the one in view lifts with a hairline + contact only, never a full card'),
 'texture': ('—', 'none'),
 'icon': ('✓', 'search 16 icon.muted; clear = close 12 on a 20 wash circle; retry 14 beside "not sent"; all from the inked set (20pt size)'),
 'tokens': ('✓', 'size.searchField, radius.control/default/panel/small, background.sunken, depth.shadow.sunken, depth.stroke.outer, surface.control/wash.pressed, background.canvas, status.dangerText, font.label; token-check 0'),
 'optical centring': ('✓', 'the search glyph sits on the field\'s cap centre (12 padding + 8 = the 18 radius); caret is ink, 2 wide, centred on the line'),
 'contrast': ('✓', 'words ≈ 15 : 1 on the underlay; meta text.label ≈ 4.6 : 1 on surface.control (passes 4.5); danger text ≈ 6 : 1; placeholder is exempt (it repeats nothing essential)'),
 'hit area': ('✓', 'whole row; field 44 tall; clear button gets a 44 tap area around its 20'),
 'states': ('✓', 'search: rest, typing (caret, clear); rows: rest, in view (lifted), pressed (surface.wash), unsent (retry); searching replaces days with matches; empty: "nothing yet. say anything."; no results: "nothing with that word yet"'),
 'motion': ('✓', 'drawer opens with the page following your finger (spring settle); results crossfade 160ms as you type; Reduce Motion: fade only'),
 'haptic': ('—', 'none for rows; a light tap only when the drawer snaps fully open (owned by the drawer page, part of M3)'),
 'goals': ('✓', 'your own words lead every row (the index is in your voice, not titles); nothing is lost: unsent notes are visible and retryable'),
 'wireframe': ('✓', 'JR-3 as drawn in mid-fi: search on top, day groups, rows of your words · what it was · time, the one in view marked'),
}
open('p23.html', 'w').write(part(23, 'drawer · search field · entry row', 'Journal\'s index: find a conversation by your own words', vis, rows,
     'revised from your comments: field darker than its underlay, body text tracked tighter (−0.02em, as iOS sets SF Pro 17), search keywords blue. ready for review.'))
