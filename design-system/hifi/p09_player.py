from review import *
# Part 09 · player sheet, round 2 (founder comments 20 Oct): the title scrolls up once the episode starts; the transcript
# has a real progressive blur top and bottom (Paper can't mask a backdrop-filter, so: a sharp copy that fades out at the
# edges over a blurred copy that fades in); chapters move into the "…" menu; "correct this part" sits above the progress line;
# holding the scrubber shows a bubble naming the chapter under your finger.
O = __import__('json').load(open('../icons/outlined-20.json'))
def icon(n, colour, size=18):
    return (f'<svg layer-name="c:icon/{n}" width="{size}" height="{size}" viewBox="0 0 24 24" style="display:inline-block;flex-shrink:0">'
            f'<path fill="{C(colour)}" fill-rule="evenodd" d="{O[n]}"/></svg>')
def line(s, colour):
    return f'<div style="width:334px;font-family:{V("font-text")};font-size:{V("text-lg")};line-height:{V("leading-normal")};color:{C(colour)}">{s}</div>'
def transcript(lines, h, top):
    # sharp copy owns the middle; the blurred copy owns the top and bottom edges; the two masks are exact inverses
    a, b = 72, h - 96
    body = ''.join(line(s, c) for s, c in lines)
    col = f'display:flex;flex-direction:column;gap:{V("spacing-4")};padding-top:{V(top)};width:334px'
    sharp = f'mask-image:linear-gradient(180deg, transparent 0px, black {a}px, black {b}px, transparent {h}px)'
    soft = f'mask-image:linear-gradient(180deg, black 0px, transparent {a}px, transparent {b}px, black {h}px)'
    return (f'<div layer-name="transcript · progressive blur" style="position:relative;width:334px;height:{h}px;flex-shrink:0;overflow:clip">'
            f'<div layer-name="lines · sharp" style="{col};{sharp}">{body}</div>'
            f'<div layer-name="lines · blurred" style="position:absolute;left:0px;top:0px;{col};filter:blur(4px);{soft}">{body}</div>'
            f'<div layer-name="edge · top" style="position:absolute;left:0px;top:0px;width:334px;height:24px;background:linear-gradient(180deg, {C("background-raised")}, transparent)"></div>'
            f'<div layer-name="edge · bottom" style="position:absolute;left:0px;bottom:0px;width:334px;height:32px;background:linear-gradient(0deg, {C("background-raised")}, transparent)"></div></div>')
L1 = "On Monday you wrote that the meeting went badly, and that you didn't want to talk about it."
L2 = 'That evening you walked to the river. Then again on Wednesday, and again on Friday.'
L3 = 'Each time, you called your sister afterwards, not before.'
L4 = "So here is a guess, and you can tell me if it's wrong."
L0 = "This week started quietly. Two short entries, a long Sunday walk."
READY = transcript([(L1, 'text-primary'), (L2, 'text-secondary'), (L3, 'text-secondary')], 300, 'spacing-10')
PLAYING = transcript([(L0, 'text-tertiary'), (L1, 'text-tertiary'), (L2, 'text-primary'), (L3, 'text-secondary'), (L4, 'text-secondary')], 388, 'spacing-6')
# once the title has scrolled away, the header carries it: the same collapse the top bar makes (ios-build-notes, top bar)
HEAD = (f'<div layer-name="header · title collapsed" style="display:flex;align-items:center;gap:{V("spacing-2")}">'
        f'<div layer-name="c:the-mark/22" style="width:22px;height:22px;flex-shrink:0;border-radius:{V("radius-control")};background:{C("surface-secondary-action")};'
        f'box-shadow:inset 0 0 0 1px {C("depth-stroke-inner-top")}, 0 0 0 1px {C("border-secondary-ring")}, 0 2px 3px {C("depth-shadow-cast")}, 0 0.5px 1px {C("depth-shadow-contact")}"></div>'
        f'<div style="width:220px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-family:{V("font-label")};font-size:{V("text-md")};font-weight:{V("font-weight-medium")};line-height:{V("leading-snug")};color:{C("text-primary")}">the week you kept choosing the river</div></div>')
def pill(t, ic=None):
    return (f'<div layer-name="c:pill/neutral/rest" style="height:36px;display:flex;align-items:center;gap:{V("spacing-2")};padding:0 {V("spacing-4")};border-radius:{V("radius-control")};background:{C("surface-wash")}">'
            + (icon(ic, 'icon-default', 16) if ic else '') + f'<div style="width:max-content;font-family:{V("font-label")};font-size:{V("text-md")};font-weight:{V("font-weight-medium")};line-height:{V("leading-snug")};color:{C("text-primary")}">{t}</div></div>')
CORRECT = f'<div layer-name="correct row" style="display:flex;padding-top:{V("spacing-4")}">{pill("correct this part", "correct")}</div>'
# the "…" menu, open: the title-menu recipe (raised panel, 44 rows, wash on the pressed row, no dividers)
def row(t, ic, trail=None):
    return (f'<div layer-name="row" style="height:44px;display:flex;align-items:center;gap:{V("spacing-3")};padding:0 {V("spacing-3")};border-radius:{V("radius-control")}">'
            f'{icon(ic, "icon-default")}<div style="flex:1;font-family:{V("font-label")};font-size:{V("text-md")};font-weight:{V("font-weight-medium")};line-height:{V("leading-snug")};color:{C("text-primary")}">{t}</div>'
            + (icon(trail, 'icon-muted', 16) if trail else '') + '</div>')
MENU = (f'<div layer-name="c:menu/more/open" style="width:220px;display:flex;flex-direction:column;padding:{V("spacing-1")};border-radius:{V("radius-card")};background:{C("background-raised")};'
        f'box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, 0 0 0 0.5px {C("depth-stroke-outer")}, 0 1px 2px {C("depth-shadow-contact")}, 0 12px 28px -12px {C("depth-shadow-cast")}, 0 24px 48px -16px {C("depth-shadow-ambient")}">'
        + row('chapters', 'chapters', 'chevron-right') + row('download', 'download') + '</div>')
# held scrub: the thumb grows 12 → 20 and a bubble rises over it with the chapter and the time under your finger
# founder 20 Oct (c-ht34pq, "poor layout"): one line, the chapter only; the times stay in the row below, whose own chapter label fades while held
BUBBLE = (f'<div layer-name="c:scrub-bubble/held" style="height:32px;box-sizing:border-box;display:flex;align-items:center;padding:0 {V("spacing-3")};border-radius:{V("radius-control")};'
          f'background:{C("background-raised")};box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, 0 0 0 0.5px {C("depth-stroke-outer")}, 0 1px 2px {C("depth-shadow-contact")}, 0 8px 20px -8px {C("depth-shadow-cast")}">'
          f'<div style="width:max-content;font-family:{V("font-label")};font-size:{V("text-md")};font-weight:{V("font-weight-medium")};line-height:{V("leading-snug")};color:{C("text-primary")}">chapter 3 · the call</div></div>')
for n, s in [('ready', READY), ('playing', PLAYING), ('head', HEAD), ('correct', CORRECT), ('menu', MENU), ('bubble', BUBBLE)]:
    open(f'p09_{n}.html', 'w').write(s)
