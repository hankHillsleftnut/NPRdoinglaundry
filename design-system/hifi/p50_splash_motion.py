# Page 06 · splash motion: keyframe exploration of the splash's opening (founder 20 Oct, c-kjkb7q:
# "start a page where you do a key frame focused exploration for the best splash screens").
# Three concepts, one per version on part 43 (A constellation, B warm light, C the product itself), five keyframes each.
# Every keyframe is a full 17 Pro phone built from tokens; motion between frames is written under each one.
from review import C, V

W, H = 402, 874
MESH = (f'background-color:{C("sky-500")};background-image:radial-gradient(circle farthest-corner at 85% 10% in oklab, {C("amber-300")} 0%, transparent 55%), '
        f'radial-gradient(circle farthest-corner at 0% 100% in oklab, {C("sky-800")} 0%, transparent 80%)')
RAISED = (f'background:{C("background-raised")};box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, 0 0 0 0.5px {C("depth-stroke-outer")}, '
          f'0 1px 2px {C("depth-shadow-contact")}, 0 12px 28px -12px {C("depth-shadow-cast")}, 0 24px 60px -20px {C("depth-shadow-ambient")}')
ORB_LIT = (f'background:radial-gradient(circle at 35% 30% in oklab, {C("glow-primary-gradient-top-lit")} 0%, {C("glow-primary-gradient-bottom")} 70%);'
           f'box-shadow:inset 0 2px 0 {C("glow-primary-rim")}, inset 0 0 14px {C("glow-primary-bloom")}, 0 0 0 1px {C("glow-primary-ring")}, 0 14px 32px -10px {C("glow-primary-halo")}')


def status():
    return (f'<div layer-name="status bar" style="position:absolute;left:0;top:0;width:{W}px;height:62px;display:flex;align-items:center;padding:0 {V("spacing-10")};box-sizing:border-box">'
            f'<div style="font-family:{V("font-text")};font-weight:{V("font-weight-semibold")};font-size:{V("text-body")};color:{C("text-primary")}">9:41</div></div>')


def words(o=1, dy=0):
    return (f'<div layer-name="words" style="position:absolute;left:0;top:{430 + dy}px;width:{W}px;padding:0 {V("spacing-screen-margin")};box-sizing:border-box;opacity:{o};display:flex;flex-direction:column;gap:{V("spacing-3")}">'
            f'<div style="font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-title")};font-size:{V("text-3xl")};line-height:{V("leading-tight")};letter-spacing:{V("tracking-title")};color:{C("text-primary")}">everything about you, finally connected.</div>'
            f'<div style="width:260px;font-family:{V("font-text")};font-size:{V("text-body")};line-height:{V("leading-snug")};color:{C("text-secondary")}">retrospect gets to know you, and tells you what it sees.</div></div>')


def buttons(o=1, dy=0):
    b = f'height:56px;border-radius:{V("radius-control")};display:flex;align-items:center;justify-content:center;font-family:{V("font-text")};font-weight:{V("font-weight-medium")};font-size:{V("text-body")}'
    return (f'<div layer-name="sign-in" style="position:absolute;left:{V("spacing-screen-margin")};top:{674 + dy}px;width:354px;display:flex;flex-direction:column;gap:{V("spacing-3")};opacity:{o}">'
            f'<div style="{b};background:{C("ink-default")};color:{C("text-inverse")}">sign in with apple</div>'
            f'<div style="{b};{RAISED};color:{C("text-primary")}">continue with google</div></div>')


def phone(inner):
    return (f'<div layer-name="keyframe · 17 Pro" style="width:{W}px;height:{H}px;flex-shrink:0;position:relative;overflow:clip;border-radius:{V("radius-sheet")};'
            f'background:{C("background-canvas")};box-shadow:inset 0 0 0 1px {C("border-subtle")}">{inner}{status()}</div>')


def frame(t, title, note, inner):
    return (f'<div layer-name="kf · {t}" style="width:{W}px;display:flex;flex-direction:column;gap:{V("spacing-3")}">{phone(inner)}'
            f'<div style="display:flex;gap:{V("spacing-2")};align-items:baseline"><div style="font-family:{V("font-mono")};font-size:{V("text-sm")};color:{C("text-label")}">{t}</div>'
            f'<div style="font-family:{V("font-label")};font-weight:{V("font-weight-medium")};font-size:{V("text-md")};color:{C("text-primary")}">{title}</div></div>'
            f'<div style="width:{W}px;font-family:{V("font-text")};font-size:{V("text-md")};line-height:{V("leading-normal")};color:{C("text-secondary")}">{note}</div></div>')


def orb(x, y, s, look):
    return f'<div style="position:absolute;left:{x - s // 2}px;top:{y - s // 2}px;width:{s}px;height:{s}px;border-radius:{V("radius-control")};{look}"></div>'


FROST = lambda tint: (f'background:radial-gradient(circle at 35% 30% in oklab, {C("background-raised")} 0%, color-mix(in oklab, {C(tint)} 55%, {C("background-raised")}) 100%);'
                      f'box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, 0 0 0 0.5px {C("depth-stroke-outer")}, 0 8px 18px -8px {C("depth-shadow-cast")}')
CX, CY = 201, 230
PEOPLE = [(-80, -50, 'sky-300', 'maya'), (85, -60, 'amber-300', 'running'), (-75, 75, 'green-300', 'work'), (100, 55, 'sky-200', 'the river')]


def ring(r, o=1):
    return (f'<div style="position:absolute;left:{CX - r}px;top:{CY - r}px;width:{2 * r}px;height:{2 * r}px;border-radius:{V("radius-control")};'
            f'box-shadow:inset 0 0 0 1px {C("border-subtle")};opacity:{o}"></div>')


def line(dx, dy, o=1):
    import math
    L = math.hypot(dx, dy); a = math.degrees(math.atan2(dy, dx))
    return (f'<svg width="{W}" height="460" viewBox="0 0 {W} 460" style="position:absolute;left:0;top:0;opacity:{o}">'
            f'<line x1="{CX}" y1="{CY}" x2="{CX + dx}" y2="{CY + dy}" stroke="{C("border-subtle")}" stroke-width="1"/></svg>')


def label(dx, dy, t, o=1):
    return (f'<div style="position:absolute;left:{CX + dx - 30}px;top:{CY + dy + 26}px;width:60px;text-align:center;font-family:{V("font-label")};'
            f'font-size:{V("text-sm")};color:{C("text-label")};opacity:{o}">{t}</div>')


def constellation(stage):
    s = ''
    if stage >= 2:
        s += ring(150, 1 if stage >= 3 else V('opacity-disabled')) + ring(95, 1 if stage >= 3 else V('opacity-disabled'))
    if stage >= 3:
        for dx, dy, tint, name in PEOPLE:
            s += line(dx, dy) + orb(CX + dx, CY + dy, 44, FROST(tint)) + label(dx, dy, name, 1 if stage >= 4 else 0)
    size = 8 if stage == 0 else 64
    look = f'background:{C("ink-default")}' if stage == 0 else ORB_LIT
    return s + orb(CX, CY, size, look)


A = [frame('0 ms', 'a point', 'plain paper, and one ink dot where you will be. no logo.', constellation(0)),
     frame('0–400 ms', 'you appear', 'the dot swells into the lit orb (spring.popover). a soft haptic as it lands.', constellation(1)),
     frame('400–900 ms', 'your world opens', 'two orbits draw outward from the orb, half-faded, like ripples.', constellation(2)),
     frame('900–1500 ms', 'the things you care about', 'four frosted orbs drift in on the orbits and connect with fine lines; their names come up last.', constellation(3) + ''),
     frame('1500–2100 ms', 'the promise', 'the words rise 12 into place, then the two buttons. the map keeps a slow drift (off with Reduce Motion).', constellation(4) + words() + buttons())]

def warm(stage):
    mask = {0: ('0%', '0%'), 1: ('18%', '48%'), 2: ('55%', '85%'), 3: ('40%', '92%'), 4: ('40%', '92%')}[stage]  # Paper can't resolve calc() in masks
    m = (f'<div layer-name="mesh" style="position:absolute;left:0;top:0;width:{W}px;height:420px;{MESH};'
         f'mask-image:linear-gradient(180deg, black 0%, black {mask[0]}, transparent {mask[1]});opacity:{0 if stage == 0 else 1}"></div>') if stage else ''
    o = orb(CX, 240, 112 if stage >= 3 else 0, ORB_LIT) if stage >= 3 else ''
    return m + o

B = [frame('0 ms', 'first light', 'plain paper. nothing yet, for one beat.', warm(0)),
     frame('0–500 ms', 'dawn at the top', "a band of the brief's sky-and-amber light appears under the status bar.", warm(1)),
     frame('500–1200 ms', 'it pours down', 'the light spreads down the screen and softens into the page (ease.out, 700ms).', warm(2)),
     frame('1200–1700 ms', 'you, lit', 'the orb surfaces from inside the light: blur 12→0, scale 0.9→1.', warm(3)),
     frame('1700–2300 ms', 'the promise', 'words and buttons rise in. the light breathes very slowly while you decide.', warm(4) + words() + buttons())]

def card(o=1, dy=0, blur=0, lit=True):
    play = (f'<div style="position:absolute;right:{V("spacing-4")};bottom:-22px;width:44px;height:44px;border-radius:{V("radius-control")};'
            + (f'background:linear-gradient(180deg, {C("glow-primary-gradient-top")}, {C("glow-primary-gradient-bottom")});box-shadow:inset 0 1px 0 {C("glow-primary-rim")}, 0 0 0 1.5px {C("glow-primary-ring")}, 0 6px 14px -4px {C("glow-primary-halo")}'
               if lit else f'background:{C("surface-wash")}') + '"></div>')
    return (f'<div layer-name="brief card" style="position:absolute;left:36px;top:{110 + dy}px;width:330px;display:flex;flex-direction:column;gap:{V("spacing-3")};padding:{V("spacing-2")};box-sizing:border-box;'
            f'border-radius:{V("radius-panel")};{RAISED};opacity:{o};filter:blur({blur}px)">'
            f'<div style="height:150px;border-radius:{V("radius-panel")};position:relative;{MESH}">{play}</div>'
            f'<div style="padding:{V("spacing-2")};font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-card")};font-size:{V("text-xl")};line-height:{V("leading-tight")};color:{C("text-primary")};width:240px">three things moved since yesterday</div></div>')

Cc = [frame('0 ms', 'a morning', 'paper, and one quiet line in the centre: "good morning." (Geist, text.label).',
            f'<div style="position:absolute;left:0;top:420px;width:{W}px;text-align:center;font-family:{V("font-label")};font-size:{V("text-md")};color:{C("text-label")}">good morning.</div>'),
      frame('300–900 ms', 'something was made for you', '"good morning." fades out as the brief card rises 40 from below, blurred and faint (opacity 0→0.7, blur 12).', card(V('opacity-pending'), 40, 12, False)),
      frame('900–1300 ms', 'it settles', 'the card comes into focus and lands with the raised shadow (spring.popover).', card(1, 0, 0, False)),
      frame('1300–1600 ms', 'the play lights', 'only then does the play glow: the one lit thing, the reason to stay.', card()),
      frame('1600–2200 ms', 'the promise', 'words and buttons rise under the card. the card stays tappable as a sample.', card() + words() + buttons())]

ROWS = [('A · constellation assembles', 'you, then your world: the map builds itself around you.', A),
        ('B · warm light', 'mood first: the brief\'s light pours in, then you surface inside it.', B),
        ('C · the product arrives', 'concrete: a real brief is made in front of you before you sign in.', Cc)]
for i, (t, d, frames) in enumerate(ROWS):
    html = (f'<div layer-name="concept" style="display:flex;flex-direction:column;gap:{V("spacing-6")}">'
            f'<div style="display:flex;flex-direction:column;gap:{V("spacing-2")}"><div style="font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-title")};font-size:{V("text-2xl")};color:{C("text-primary")}">{t}</div>'
            f'<div style="font-family:{V("font-text")};font-size:{V("text-md")};color:{C("text-secondary")}">{d}</div></div>'
            f'<div style="display:flex;gap:{V("spacing-10")};align-items:flex-start">' + ''.join(frames) + '</div></div>')
    open(f'p50_row{i}.html', 'w').write(html)
print('ok')
