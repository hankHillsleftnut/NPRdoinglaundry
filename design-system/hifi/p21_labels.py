# Part 21 · labels: the three small words that organise a list. Geist only (type.md: 500 for section labels, 400 for meta).
from review import *
def lab(kind, text, align='left'):
    w = V('font-weight-medium')
    return (f'<div layer-name="c:label/{kind}/rest" style="font-family:{V("font-label")};font-size:{V("text-sm")};font-weight:{w};line-height:{V("leading-snug")};'
            f'letter-spacing:{V("tracking-label")};color:{C("text-label")};text-align:{align};white-space:nowrap">{text}</div>')
def ph(name, h):  # a stand-in for a neighbouring part (built elsewhere), so only the label is being judged here
    return (f'<div layer-name="stand-in · {name}" style="height:{h}px;border-radius:{V("radius-default")};outline:0.5px dashed {C("border-strong")};outline-offset:-0.5px;'
            f'display:flex;align-items:center;justify-content:center;font-family:{V("font-label")};font-size:{V("text-xs")};color:{C("text-tertiary")}">{name}</div>')
def col(*xs, gap='spacing-2', w=None, extra=''):
    return f'<div style="display:flex;flex-direction:column;gap:{V(gap)};' + (f'width:{w}px;' if w else '') + f'{extra}">' + ''.join(xs) + '</div>'
thread = col(col(lab('day', 'yesterday', 'center'), ph('message · yours', 44), ph('message · retro', 64), gap='spacing-2'),
             col(lab('day', 'today', 'center'), ph('message · yours', 44), gap='spacing-2'), gap='spacing-10', w=326)
drawer = col(col(lab('day', 'today'), ph('entry row 56', 56), gap='spacing-2'),
             col(lab('day', 'yesterday'), ph('entry row 56', 56), ph('entry row 56', 56), gap='spacing-2'),
             col(lab('day', 'tue 14 oct'), ph('entry row 56', 56), gap='spacing-2'), gap='spacing-6', w=300)
settings = col(col(lab('section', 'what retro can see'), ph('settings row 56', 56), ph('settings row 56', 56), gap='spacing-3'),
               col(lab('section', 'your data'), ph('settings row 56', 56), gap='spacing-3'), gap='spacing-8', w=326)
vis = (tile(thread, '1× · day label in the Journal thread · centred · 8 above its first message, 40 between days (rule 32)')
       + tile(drawer, '1× · day label in the drawer · leading edge · 8 above its rows, 24 between days')
       + tile(settings, '1× · section label above a settings group · 12 above its rows, 32 between groups'))
rows = {
 'purpose': ('✓', 'labels name a group so you can find your place; they never act, so they never look tappable'),
 'colour': ('✓', 'text.label (paper 620) on the canvas: quieter than the content it heads, louder than the background'),
 'type': ('✓', 'Geist 500, 12 (text.sm), tracking.label +0.01em, leading.snug; lowercase. Relative days ("today", "yesterday", a weekday) up to 6 days, then "tue 14 oct". The mid-fi\'s serif settings titles are replaced: type.md says section labels are Geist 500'),
 'space': ('✓', 'thread: 8 above the first message, 40 between days (rule 32). drawer: 8 above, 24 between days. settings: 12 above the group, 32 between groups (space.section)'),
 'shape': ('—', 'no container: grouping by space, not lines or pills (layout rule: space first)'),
 'depth': ('✓', 'page level 0: content, never raised (surfaces rule 2)'),
 'texture': ('—', 'none'),
 'icon': ('—', 'none: a word is clearer than a calendar glyph here'),
 'tokens': ('✓', 'font.label, text.sm, font.weight.medium, tracking.label, leading.snug, text.label, spacing 2 / 3 / 6 / 8 / 10; token-check 0'),
 'optical centring': ('✓', 'thread labels centre on the reading column (326), not the screen, so they sit over the messages they head'),
 'contrast': ('✓', 'text.label on canvas ≈ 5.1 : 1 (passes 4.5 at 12pt)'),
 'hit area': ('—', 'not interactive; VoiceOver treats each as a header (accessibilityAddTraits(.isHeader)), so rotor jumps work'),
 'states': ('✓', 'rest only; sticky in the drawer (the current day pins under the search field while its rows scroll); Dynamic Type grows them to AX3, then they wrap'),
 'motion': ('✓', 'the drawer\'s sticky label swaps with a 120ms crossfade when the next day pushes it up; Reduce Motion: instant'),
 'haptic': ('—', 'none'),
 'goals': ('✓', 'Journal is one thread grouped by day (rule 29); the drawer is its index by day; labels make both scannable'),
 'wireframe': ('✓', 'same positions as the mid-fi (JR-1 day labels, JR-3 drawer days, Settings groups); settings titles change from serif to Geist'),
}
open('p21.html', 'w').write(part(21, 'labels · day · section', 'the small words that tell you where you are', vis, rows,
     'ready for your review. note: settings group titles move from the mid-fi\'s serif to Geist 500, per type.md.'))
