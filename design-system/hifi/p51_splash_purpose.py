# Page 06 · splash openings that say what the product is for (founder 20 Oct, c-nokaqr:
# "come up with more ideas, they should be more focused on communicating the purpose of the product, not just being pretty").
# Purpose in one line: you talk and live, Retrospect connects it, and tells you what it sees (a brief, an episode, an insight).
# Each row: four drawn keyframes, then the real part 43 A splash (duplicated in Paper as the fifth frame).
from review import C, V

W = 402
WALL = (f'background-color:{C("background-canvas")};background-image:radial-gradient(65% 34% at 90% 0% in oklab, color-mix(in oklab, {C("amber-200")} 34%, transparent) 0%, transparent 100%), '
        f'radial-gradient(70% 38% at 0% 18% in oklab, color-mix(in oklab, {C("sky-200")} 36%, transparent) 0%, transparent 100%)')
RAISED = (f'background:{C("background-raised")};box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, 0 0 0 0.5px {C("depth-stroke-outer")}, '
          f'0 1px 2px {C("depth-shadow-contact")}, 0 10px 24px -12px {C("depth-shadow-cast")}')
ORB = (f'background:radial-gradient(circle at 35% 30% in oklab, {C("glow-primary-gradient-top-lit")} 0%, {C("glow-primary-gradient-bottom")} 70%);'
       f'box-shadow:inset 0 2px 0 {C("glow-primary-rim")}, inset 0 0 14px {C("glow-primary-bloom")}, 0 0 0 1px {C("glow-primary-ring")}, 0 14px 32px -10px {C("glow-primary-halo")}')
MESH = (f'background-color:{C("night-800")};background-image:radial-gradient(110% 120% at 92% 0% in oklab, {C("amber-200")} 0%, transparent 55%), '
        f'radial-gradient(90% 90% at 55% 40% in oklab, color-mix(in oklab, {C("amber-600")} 70%, transparent) 0%, transparent 100%), '
        f'radial-gradient(100% 100% at 0% 100% in oklab, {C("night-950")} 0%, transparent 90%)')


def status():
    return (f'<div style="position:absolute;left:0;top:0;width:{W}px;height:62px;display:flex;align-items:center;padding:0 {V("spacing-10")};box-sizing:border-box">'
            f'<div style="font-family:{V("font-text")};font-weight:{V("font-weight-semibold")};font-size:{V("text-body")};color:{C("text-primary")}">9:41</div></div>')


def phone(inner):
    return (f'<div layer-name="keyframe · 17 Pro" style="width:{W}px;height:874px;flex-shrink:0;position:relative;overflow:clip;border-radius:{V("radius-sheet")};{WALL};'
            f'box-shadow:inset 0 0 0 1px {C("border-subtle")}">{inner}{status()}</div>')


def frame(t, title, note, inner=None):
    ph = phone(inner) if inner is not None else ''
    return (f'<div layer-name="kf · {t}" style="width:{W}px;display:flex;flex-direction:column;gap:{V("spacing-3")}">{ph}'
            f'<div style="display:flex;gap:{V("spacing-2")};align-items:baseline"><div style="font-family:{V("font-mono")};font-size:{V("text-sm")};color:{C("text-label")}">{t}</div>'
            f'<div style="font-family:{V("font-label")};font-weight:{V("font-weight-medium")};font-size:{V("text-md")};color:{C("text-primary")}">{title}</div></div>'
            f'<div style="width:{W}px;font-family:{V("font-text")};font-size:{V("text-md")};line-height:{V("leading-normal")};color:{C("text-secondary")}">{note}</div></div>')


def chip(x, y, kind, text, extra=''):
    dot = {'voice': C('sky-400'), 'calendar': C('amber-300'), 'note': C('night-400'), 'health': C('green-300')}[kind]
    return (f'<div style="position:absolute;left:{x}px;top:{y}px;display:flex;align-items:center;gap:{V("spacing-2")};padding:{V("spacing-2")} {V("spacing-3")};'
            f'border-radius:{V("radius-control")};{RAISED};{extra}"><div style="width:8px;height:8px;border-radius:{V("radius-control")};background:{dot}"></div>'
            f'<div style="width:max-content;font-family:{V("font-label")};font-size:{V("text-sm")};color:{C("text-primary")}">{text}</div></div>')


def orb(cx, cy, s, extra=''):
    return f'<div style="position:absolute;left:{cx - s // 2}px;top:{cy - s // 2}px;width:{s}px;height:{s}px;border-radius:{V("radius-control")};{ORB};{extra}"></div>'


def line(pts):
    return (f'<svg width="{W}" height="874" viewBox="0 0 {W} 874" style="position:absolute;left:0;top:0">'
            + ''.join(f'<line x1="{a}" y1="{b}" x2="{c}" y2="{d}" stroke="{C("sky-400")}" stroke-opacity="0.5" stroke-width="1.5"/>' for a, b, c, d in pts) + '</svg>')


def inky(x, y, w, text, size='text-2xl', colour='text-primary', extra=''):
    return (f'<div style="position:absolute;left:{x}px;top:{y}px;width:{w}px;font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-title")};'
            f'font-size:{V(size)};line-height:{V("leading-tight")};letter-spacing:{V("tracking-title")};color:{C(colour)};{extra}">{text}</div>')


def label(x, y, w, text, align='left'):
    return (f'<div style="position:absolute;left:{x}px;top:{y}px;width:{w}px;text-align:{align};font-family:{V("font-label")};font-size:{V("text-sm")};'
            f'color:{C("text-label")}">{text}</div>')


FRAGS = [(40, 150, 'voice', 'voice note · 1:42'), (214, 196, 'calendar', '9am standup, again'), (60, 262, 'note', '"slept badly"'),
         (196, 318, 'health', 'ran 5k at 7'), (48, 388, 'note', '"felt sharp before 9"'), (210, 440, 'calendar', 'sunday call with mum')]
FAINT = f'opacity:{V("opacity-disabled")};filter:blur(2px)'

# D · your life becomes the dots, and the dots connect
D = [frame('0–600 ms', 'pieces of a week', 'the things you said and did appear one by one, scattered and faint: a voice note, a meeting, a run, something you wrote.',
           ''.join(chip(x, y, k, t, FAINT if i % 2 else '') for i, (x, y, k, t) in enumerate(FRAGS))),
     frame('600–1300 ms', 'they connect', 'thin lines of light find what goes together: the mornings, the standup, the sleep. you see the product working.',
           ''.join(chip(x, y, k, t) for x, y, k, t in FRAGS) + line([(120, 170, 120, 280), (120, 280, 130, 406), (290, 214, 286, 336), (286, 336, 130, 406)])),
     frame('1300–1900 ms', 'one thing it sees', 'the pieces draw together into you, and one sentence appears: what retro noticed.',
           ''.join(chip(x, y, k, t, f'opacity:{V("opacity-disabled")}') for x, y, k, t in FRAGS[:3]) + orb(201, 330, 72)
           + inky(24, 430, 354, 'your best days start early.', 'text-2xl') + label(24, 476, 354, 'from 3 mornings, 2 runs and what you said on monday')),
     frame('1900–2400 ms', 'and it becomes a map', 'the sentence lifts away and the pieces settle as your map around you.',
           orb(201, 230, 66) + ''.join(chip(x, y, k, t, f'opacity:{V("opacity-pending")}') for x, y, k, t in [(30, 130, 'voice', 'voice'), (262, 140, 'health', 'running'), (40, 300, 'note', 'work'), (250, 296, 'calendar', 'mum')])),
     frame('2400–3000 ms', 'the promise', 'lands on the real splash (part 43 A).')]

# E · it listens, then it tells you
WAVE = ''.join(f'<div style="width:4px;height:{h}px;border-radius:{V("radius-control")};background:{C("voice-listening")}"></div>' for h in (10, 22, 34, 18, 28, 12, 24, 16))
E = [frame('0–700 ms', 'you say something', 'a voice comes in: the bars move and your words appear as you say them.',
           f'<div style="position:absolute;left:24px;top:300px;display:flex;gap:{V("spacing-1")};align-items:center;height:40px">{WAVE}</div>'
           + inky(24, 360, 354, 'i think it’s the 9am standup. i dread it.', 'text-2xl', extra=f'font-family:{V("font-text")};font-weight:{V("font-weight-regular")};letter-spacing:{V("tracking-card")}')),
     frame('700–1400 ms', 'it remembers', 'faint cards of earlier mondays slide in behind your words: it has been listening for a while.',
           chip(24, 250, 'calendar', 'mon 6 oct · standup', FAINT) + chip(150, 210, 'calendar', 'mon 13 oct · standup', FAINT) + chip(220, 270, 'note', '"dreading monday"', FAINT)
           + inky(24, 360, 354, 'i think it’s the 9am standup. i dread it.', 'text-2xl', extra=f'font-family:{V("font-text")};font-weight:{V("font-weight-regular")};letter-spacing:{V("tracking-card")}')),
     frame('1400–2100 ms', 'and it tells you', 'retro answers in ink, the thing a friend who remembers would say.',
           inky(24, 300, 354, 'i think it’s the 9am standup. i dread it.', 'text-lg', 'text-secondary', f'font-family:{V("font-text")};font-weight:{V("font-weight-regular")};letter-spacing:{V("tracking-card")}')
           + inky(24, 380, 354, 'third monday like that. what’s different about mondays?', 'text-2xl') + label(24, 470, 354, 'from your last 3 mondays')),
     frame('2100–2600 ms', 'every week, an episode', 'the answer folds into this week’s episode card with its play: listening becomes a podcast about you.',
           f'<div style="position:absolute;left:36px;top:180px;width:330px;padding:{V("spacing-2")};box-sizing:border-box;border-radius:{V("radius-panel")};{RAISED}">'
           f'<div style="height:150px;border-radius:{V("radius-panel")};{MESH}"></div>'
           f'<div style="padding:{V("spacing-3")} {V("spacing-2")};font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-card")};font-size:{V("text-xl")};line-height:{V("leading-tight")};color:{C("text-primary")}">the week you stopped rushing</div></div>'),
     frame('2600–3200 ms', 'the promise', 'lands on the real splash (part 43 A).')]

# F · a year, gathered: time collapses into one view of you
DAYS = ''.join(f'<div style="width:22px;height:22px;border-radius:{V("radius-default")};background:{C("sky-200") if (i * 7) % 5 else C("amber-200")};opacity:{V("opacity-pending") if i % 3 else 1}"></div>' for i in range(48))
GRID = f'<div style="position:absolute;left:47px;top:200px;width:308px;display:flex;flex-wrap:wrap;gap:{V("spacing-1")}">{DAYS}</div>'
F = [frame('0–600 ms', 'your days', 'twelve weeks of days fill in as small squares: each one something you lived and said.', GRID),
     frame('600–1200 ms', 'patterns light up', 'the days that share something glow together (the warm ones are your early mornings).',
           GRID + f'<div style="position:absolute;left:30px;top:180px;width:342px;height:200px;border-radius:{V("radius-panel")};background:radial-gradient(60% 60% at 30% 40% in oklab, color-mix(in oklab, {C("amber-200")} 40%, transparent) 0%, transparent 100%)"></div>'),
     frame('1200–1900 ms', 'they gather into you', 'all the days pull into the centre and become the orb: you, made of your days.',
           orb(201, 300, 96, f'box-shadow:0 0 0 18px color-mix(in oklab, {C("sky-200")} 30%, transparent), 0 0 0 48px color-mix(in oklab, {C("sky-100")} 14%, transparent), 0 14px 32px -10px {C("glow-primary-halo")}')),
     frame('1900–2500 ms', 'and it speaks', 'one inky line: what all those days add up to.', orb(201, 230, 66) + inky(24, 330, 354, 'you’re calmer when you move before nine.', 'text-2xl') + label(24, 420, 354, 'from 12 weeks')),
     frame('2500–3100 ms', 'the promise', 'lands on the real splash (part 43 A).')]

ROWS = [('D · the dots connect', 'shows the product working: the pieces of your week appear, connect, and become one thing it sees about you.', D),
        ('E · it listens, then it tells you', 'shows the loop: you talk, it remembers, it answers like a friend who was paying attention, and every week it becomes an episode.', E),
        ('F · your days, gathered', 'shows the scale: weeks of your life become one view of you, and one true sentence.', F)]
for i, (t, d, frames) in enumerate(ROWS):
    html = (f'<div layer-name="concept · {t}" style="display:flex;flex-direction:column;gap:{V("spacing-6")}">'
            f'<div style="display:flex;flex-direction:column;gap:{V("spacing-2")}"><div style="font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-title")};font-size:{V("text-2xl")};color:{C("text-primary")}">{t}</div>'
            f'<div style="font-family:{V("font-text")};font-size:{V("text-md")};color:{C("text-secondary")}">{d}</div></div>'
            f'<div layer-name="frames" style="display:flex;gap:{V("spacing-10")};align-items:flex-start">' + ''.join(frames) + '</div></div>')
    open(f'p51_row{i}.html', 'w').write(html)
print('ok')
