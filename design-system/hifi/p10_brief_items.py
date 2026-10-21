from review import *
import json
# Part 10 · brief items + recap card (M2: the "now" card, the up-next rows, the recap card). From the JR-2 / JR-1 mid-fi:
# the brief is heard, not read, so only the part being spoken is shown in full (with why it's here and its source);
# what comes next is one quiet line each. A recap is a finished conversation folded into one card in the thread.
O = json.load(open('../icons/outlined-20.json'))
def icon(n, colour, size=12):
    return (f'<svg layer-name="c:icon/{n}" width="{size}" height="{size}" viewBox="0 0 24 24" style="display:inline-block;flex-shrink:0">'
            f'<path fill="{C(colour)}" fill-rule="evenodd" d="{O[n]}"/></svg>')
def lab(s, colour='text-label', weight='font-weight-regular'):
    return f'<div style="font-family:{V("font-label")};font-size:{V("text-sm")};line-height:{V("leading-snug")};font-weight:{V(weight)};color:{C(colour)}">{s}</div>'
RAISED = (f'background:{C("background-raised")};box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, 0 0 0 0.5px {C("depth-stroke-outer")}, '
          f'0 1px 2px {C("depth-shadow-contact")}, 0 12px 28px -12px {C("depth-shadow-cast")}')
def open_link(s):
    return f'<div style="display:flex;align-items:center;gap:{V("spacing-1")}">{lab(s)}{icon("chevron-right", "text-label")}</div>'
NOW = (f'<div layer-name="c:brief-item/now/playing" style="width:342px;display:flex;flex-direction:column;gap:{V("spacing-2")};padding:{V("spacing-4")};border-radius:{V("radius-panel")};{RAISED}">'
       + f'<div style="display:flex;justify-content:space-between">{lab("playing now", "accent-text", "font-weight-medium")}<div style="font-family:{V("font-mono")};font-size:{V("text-sm")};color:{C("text-label")}">1 of 3</div></div>'
       + f'<div style="width:310px;font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-card")};font-size:{V("text-lg")};line-height:{V("leading-snug")};letter-spacing:{V("tracking-tight")};color:{C("text-primary")}">the fundraise article you sent</div>'
       + f'<div style="width:310px;font-family:{V("font-text")};font-size:{V("text-md")};line-height:{V("leading-snug")};color:{C("text-secondary")}">here for your goal: raise the seed</div>'
       + open_link('from the link you sent yesterday, 9:14') + '</div>')
def next_row(n, s):
    return (f'<div layer-name="c:brief-item/next/rest" style="width:342px;height:{V("spacing-size-row-compact")};display:flex;align-items:center;gap:{V("spacing-3")};padding:0 {V("spacing-4")};box-sizing:border-box">'
            f'<div style="width:16px;font-family:{V("font-mono")};font-size:{V("text-sm")};color:{C("text-tertiary")}">{n}</div>'
            f'<div style="flex:1;font-family:{V("font-text")};font-size:{V("text-md")};color:{C("text-secondary")}">{s}</div></div>')
NEXT = (f'<div layer-name="up next" style="display:flex;flex-direction:column;gap:{V("spacing-1")}"><div style="padding:0 {V("spacing-4")}">{lab("next", weight="font-weight-medium")}</div>'
        + next_row(2, 'four meetings before noon') + next_row(3, 'five hours of sleep, two nights running') + '</div>')
RECAP = (f'<div layer-name="c:recap-card/rest" style="width:342px;display:flex;flex-direction:column;gap:{V("spacing-1")};padding:{V("spacing-4")};border-radius:{V("radius-panel")};background:{C("surface-wash")}">'
         + f'<div style="font-family:{V("font-text")};font-size:{V("text-body")};letter-spacing:{V("tracking-card")};font-weight:{V("font-weight-medium")};line-height:{V("leading-snug")};color:{C("text-primary")}">your first conversation with retro</div>'
         + open_link('9 answers · 12 min · open') + '</div>')
vis = (tile(f'<div style="display:flex;flex-direction:column;gap:{V("spacing-6")}">{NOW}{NEXT}</div>', 'now + next · the spoken part in full on a raised card; the rest one quiet line each')
       + tile(RECAP, 'recap · a finished conversation, folded to one card in the thread (wash, no shadow)'))
open('p10_tiles.html', 'w').write(vis)
