from review import *
import json
# Part 06 · Journal top bar · two versions plus the scrolled state (M2, shared: top bar).
# Built true 1× with dashed hit-area guides (shared rule with the other session); inspect by 3× screenshot.
DRAWER = json.load(open('../icons/outlined-20.json'))['drawer']
STATUS = ('<div layer-name="Status bar" style="display: flex; align-items: center; gap: 154px; padding: 21px 24px 19px;"><div layer-name="Time" style="display: flex; flex-direction: column; align-items: center; justify-content: center; flex: 1;"><div style="color: black; font-family: system-ui; font-size: 17px; font-weight: 600; text-align: center; width: fit-content">9:41</div></div><div layer-name="Icons" style="display: flex; flex-direction: column; flex: 1; align-items: center; justify-content: center;"><svg width="82" height="22" viewBox="0 0 82 22" style="flex-shrink: 0" fill="black"><path d="M3.7 13H2.5a1 1 0 0 0-1 1v2.5a1 1 0 0 0 1 1h1.2a1 1 0 0 0 1-1V14a1 1 0 0 0-1-1m5.2-2.5H7.7a1 1 0 0 0-1 1v5a1 1 0 0 0 1 1h1.2a1 1 0 0 0 1-1v-5a1 1 0 0 0-1-1M14.1 8h-1.2a1 1 0 0 0-1 1v7.5a1 1 0 0 0 1 1h1.2a1 1 0 0 0 1-1V9a1 1 0 0 0-1-1m5.2-2.5h-1.2a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h1.2a1 1 0 0 0 1-1v-10a1 1 0 0 0-1-1" /><path fill-rule="evenodd" d="M36.57 7.8c2.49 0 4.88.92 6.68 2.58.14.13.36.12.49 0l1.3-1.27a.34.34 0 0 0 0-.5 12.55 12.55 0 0 0-16.93 0 .34.34 0 0 0 0 .5l1.3 1.26c.13.13.34.14.48 0a10 10 0 0 1 6.68-2.57m0 4.22a5.4 5.4 0 0 1 3.67 1.44c.14.13.35.13.48 0l1.3-1.33a.37.37 0 0 0-.01-.52 7.9 7.9 0 0 0-10.88 0 .37.37 0 0 0 0 .52l1.29 1.32c.13.14.34.14.48 0 1-.92 2.31-1.43 3.67-1.43m2.52 2.8q0 .15-.1.28l-2.18 2.45a.3.3 0 0 1-.24.11.3.3 0 0 1-.24-.1l-2.18-2.46a.43.43 0 0 1 .01-.56 3.44 3.44 0 0 1 4.82 0 .4.4 0 0 1 .11.28" clip-rule="evenodd" /><path fill-rule="evenodd" d="M70.5 5c2.05 0 3.08 0 3.88.34a4.3 4.3 0 0 1 2.28 2.28c.34.8.34 1.83.34 3.88s0 3.08-.34 3.88a4.3 4.3 0 0 1-2.28 2.28c-.8.34-1.83.34-3.88.34h-12c-2.05 0-3.08 0-3.88-.34a4.3 4.3 0 0 1-2.28-2.28c-.34-.8-.34-1.83-.34-3.88s0-3.08.34-3.88a4.3 4.3 0 0 1 2.28-2.28C55.42 5 56.45 5 58.5 5zM58.28 6c-1.85 0-2.77 0-3.48.36a3.3 3.3 0 0 0-1.44 1.44C53 8.5 53 9.43 53 11.28v.44c0 1.85 0 2.77.36 3.48a3.3 3.3 0 0 0 1.44 1.44c.7.36 1.63.36 3.48.36h12.44c1.85 0 2.77 0 3.48-.36a3.3 3.3 0 0 0 1.44-1.44c.36-.7.36-1.63.36-3.48v-.44c0-1.85 0-2.77-.36-3.48a3.3 3.3 0 0 0-1.44-1.44C73.5 6 72.57 6 70.72 6z" clip-rule="evenodd" style="opacity: .35" /><path d="M54 11c0-1.4 0-2.1.27-2.63a2.5 2.5 0 0 1 1.1-1.1C55.9 7 56.6 7 58 7h13c1.4 0 2.1 0 2.64.27q.72.37 1.09 1.1C75 8.9 75 9.6 75 11v1c0 1.4 0 2.1-.27 2.64a2.5 2.5 0 0 1-1.1 1.09C73.1 16 72.4 16 71 16H58c-1.4 0-2.1 0-2.63-.27a2.5 2.5 0 0 1-1.1-1.1C54 14.1 54 13.4 54 12z" /><path d="M78 9.5v4.08a2.2 2.2 0 0 0 1.33-2.04A2.2 2.2 0 0 0 78 9.5" style="opacity: .35" /></svg></div></div>')
def drawer_button(guide=True):
    ring = f'outline:1px dashed {C("text-link")};outline-offset:-1px;' if guide else ''
    return (f'<div layer-name="hit area 44" style="width:44px;height:44px;flex-shrink:0;display:flex;align-items:center;justify-content:center;{ring}">'
            f'<div layer-name="c:icon-button/wash/rest" style="width:36px;height:36px;border-radius:{V("radius-control")};background:{C("surface-wash")};display:flex;align-items:center;justify-content:center">'
            f'<svg layer-name="c:icon/drawer" width="20" height="20" viewBox="0 0 24 24" style="display:inline-block;flex-shrink:0"><path fill="{C("icon-default")}" fill-rule="evenodd" d="{DRAWER}"/></svg></div></div>')
SPACER = '<div style="width:44px;height:44px;flex-shrink:0"></div>'
def bar(inner, name):
    return (f'<div layer-name="c:top-bar/{name}/rest" style="height:{V("spacing-size-nav-bar")};display:flex;align-items:center;'
            f'padding:0 {V("spacing-4")};gap:{V("spacing-2")}">{inner}</div>')
small_label = f'<div style="flex:1;display:flex;justify-content:center;font-family:{V("font-label")};font-size:{V("text-md")};font-weight:{V("font-weight-medium")};letter-spacing:{V("tracking-label")};color:{C("text-secondary")}">journal</div>'
inky_title = (f'<div style="flex:1;font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-title")};font-size:{V("text-3xl")};'
              f'line-height:{V("leading-tight")};letter-spacing:{V("tracking-title")};color:{C("text-primary")}">journal</div>')
A_BAR = bar(drawer_button() + small_label + SPACER, 'label')
B_BAR = bar(drawer_button() + inky_title, 'title')
def phone(top, body='', h=140, name='phone · top'):
    return (f'<div layer-name="{name}" style="width:390px;height:{h}px;position:relative;overflow:hidden;background:{C("background-canvas")};'
            f'border-radius:{V("radius-sheet")} {V("radius-sheet")} 0 0;box-shadow:inset 0 0 0 1px {C("border-subtle")}">{body}'
            f'<div layer-name="chrome" style="position:absolute;left:0;top:0;width:390px">{STATUS}{top}</div></div>')
# the scrolled state: the thread passes under the bar, sharp copy masked out, blurred copy masked in (a real progressive blur, as the tab bar)
MSG = (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-3")}"><div style="max-width:300px;font-family:{V("font-text")};font-size:{V("text-body")};letter-spacing:{V("tracking-card")};line-height:{V("leading-normal")};color:{C("text-primary")}">third monday like that. what\'s different about mondays?</div>'
       f'<div style="align-self:flex-end;max-width:250px;padding:{V("spacing-3")} {V("spacing-4")};border-radius:{V("radius-message")} {V("radius-message")} {V("spacing-size-border-inset")} {V("radius-message")};background:{C("message-mine")};font-family:{V("font-text")};font-size:{V("text-body")};letter-spacing:{V("tracking-card")};line-height:{V("leading-snug")};color:{C("text-primary")}">i think it\'s the 9am standup. i dread it.</div></div>')
def layer(mask, extra=''):
    return f'<div style="position:absolute;left:0;right:0;top:{V("spacing-12")};padding:{V("spacing-4")} {V("spacing-6")};mask-image:{mask};{extra}">{MSG}</div>'
SCROLLED = (layer('linear-gradient(180deg, transparent 30%, black 60%)') + layer('linear-gradient(180deg, black 30%, transparent 60%)', 'filter:blur(6px);')
            + f'<div layer-name="canvas tint" style="position:absolute;left:0;right:0;top:0;height:110px;background:linear-gradient(180deg, {C("background-canvas")} 45%, transparent 100%)"></div>')
vis = (tile(phone(A_BAR), 'A · label · drawer, the page named small and quiet; the brief card is the first big thing')
       + tile(phone(B_BAR), 'B · inky title · drawer, then "journal" in the inky face, as Podcasts and You will')
       + tile(phone(A_BAR, SCROLLED, 220, 'phone · scrolled'), 'A · scrolled · the thread dissolves under the bar (same blur as the tab bar)'))
open('p06_tiles.html', 'w').write(vis)
