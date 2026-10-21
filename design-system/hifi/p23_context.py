from review import *
# Part 23 · in the app: the journal drawer open on a 390×844 phone (rule: every part ships with its in-app phone, from the founder's
# "what is this" comments). The drawer is the grey underlay under the journal; the journal slides right and stays visible as the way back.
import importlib.util
def load(n):
    spec = importlib.util.spec_from_file_location(n, f'{n}.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
d, t = load('p23_drawer'), load('p06_topbar')
DRAWER = (f'<div layer-name="drawer" style="position:absolute;left:0;top:0;width:316px;height:844px;padding:{V("spacing-16")} {V("spacing-4")} 0;'
          f'display:flex;flex-direction:column;gap:{V("spacing-4")}">'
          + d.search('rest')
          + d.group(d.day('today'), d.entry("i think it's the 9am standup. i dread it.", '3 messages · retro replied · 9:12', 'here'))
          + d.group(d.day('yesterday'), d.entry('slept badly, long day of meetings', '2 messages · 22:40'),
                    d.entry('on the walk home i kept thinking about the offer, and…', 'voice note · 1:42'),
                    d.entry('the fundraise article you shared', 'not sent · tap to retry', 'unsent'))
          + d.group(d.day('sun 19 oct'), d.entry('long walk, first good sleep in a week', '4 messages · 21:05')) + '</div>')
PAGE = (f'<div layer-name="journal (pushed right)" style="position:absolute;left:316px;top:0;width:390px;height:844px;background:{C("background-canvas")};'
        f'border-radius:{V("radius-sheet")};box-shadow:0 0 0 0.5px {C("depth-stroke-outer")}, 0 4px 12px {C("shadow-overlay-2")}, 0 24px 48px -12px {C("shadow-overlay-1")};overflow:clip">'
        + '<div layer-name="status bar space" style="height:62px"></div>' + t.bar(t.drawer_button(False) + t.small_label + t.SPACER, "label") + f'<div style="padding:{V("spacing-4")} {V("spacing-6")}">{t.MSG}</div></div>')
FOOT = load('m4_pages').foot(316, False)  # settings · version at the foot (mid-fi; restored in M4, founder yes)
PHONE = (f'<div layer-name="phone · journal drawer open" style="width:390px;height:844px;flex-shrink:0;position:relative;overflow:clip;'
         f'background:{C("surface-control")};border-radius:{V("radius-sheet")};box-shadow:inset 0 0 0 1px {C("border-subtle")}">{DRAWER}{FOOT}{PAGE}<div layer-name="status bar (fixed over both layers)" style="position:absolute;left:0;top:0;width:390px">{t.STATUS}</div></div>')
CAP = (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-1")};width:390px">'
       f'<div style="font-family:{V("font-label")};font-size:{V("text-sm")};font-weight:{V("font-weight-medium")};color:{C("text-primary")}">in the app, 1× · the journal drawer, open</div>'
       f'<div style="font-family:{V("font-text")};font-size:{V("text-md")};line-height:{V("leading-snug")};color:{C("text-secondary")}">'
       'tap the drawer button (or swipe right) on the journal: the journal slides aside and this list sits under it. each line is one conversation, in your own words, grouped by day; '
       'the one you were in is lifted. search finds any of them by a word you said. tap a line to jump there; tap the journal edge to close.</div></div>')
HTML = f'<div layer-name="part 23 · in the app" style="display:flex;flex-direction:column;gap:{V("spacing-4")}">{PHONE}{CAP}</div>'
open('p23_ctx.html', 'w').write(HTML)
