# Decision cards for 02b (founder, 20 Oct: "one card per change per component... make it extremely clear which are the options,
# which one we've chosen and what's archived"). One artboard per decision; this builds its contents.
# Reads top to bottom: status + question · what it is / how it works / what changed · options side by side, each with a big
# letter, a status chip, what it's good at (+) and what it costs (−) · how to answer. The 15 checks live in docs, not here.
from review import V, C

def _t(s, size='text-md', color='text-secondary', fam='font-text', w='font-weight-regular', extra=''):
    return (f'<div style="font-family:{V(fam)};font-size:{V(size)};font-weight:{V(w)};line-height:{V("leading-snug")};'
            f'color:{C(color)};{extra}">{s}</div>')

def _kicker(s):
    return _t(s, 'text-sm', 'text-label', 'font-label', 'font-weight-medium', f'letter-spacing:{V("tracking-label")}')

STATUS = {  # chip text, fill, text colour
    'open': ('open · needs your call', 'ink-default', 'text-inverse'),
    'chosen': ('chosen', 'ink-default', 'text-inverse'),
    'lean': ('my lean', 'surface-wash-pressed', 'text-primary'),
    'current': ('as drawn now', 'surface-wash', 'text-secondary'),
    'archived': ('archived', 'surface-wash', 'text-tertiary'),
}
def chip(kind):
    text, bg, fg = STATUS[kind]
    return _t(text, 'text-sm', fg, 'font-label', 'font-weight-medium',
              f'padding:{V("spacing-1")} {V("spacing-3")};border-radius:{V("radius-control")};background:{C(bg)};white-space:nowrap')

def option(letter, title, visual, good, cost, status=()):
    strong = 'chosen' in status or 'lean' in status
    tag = (f'<div style="width:36px;height:36px;flex-shrink:0;border-radius:{V("radius-control")};background:{C("ink-default" if strong else "surface-wash-pressed")};'
           f'display:flex;align-items:center;justify-content:center;font-family:{V("font-label")};font-size:{V("text-base")};font-weight:{V("font-weight-medium")};'
           f'color:{C("text-inverse" if strong else "text-primary")}">{letter}</div>')
    head = (f'<div style="display:flex;align-items:center;gap:{V("spacing-3")}">' + tag
            + _t(title, 'text-base', 'text-primary', 'font-label', 'font-weight-medium', 'flex:1') + ''.join(chip(s) for s in status) + '</div>')
    notes = (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-1")}">'
             + _t('+ ' + good, 'text-md', 'text-secondary') + _t('− ' + cost, 'text-md', 'text-secondary') + '</div>')
    return (f'<div layer-name="option {letter} · {title}" style="width:440px;flex-shrink:0;display:flex;flex-direction:column;gap:{V("spacing-4")};'
            f'padding:{V("spacing-5")};border-radius:{V("radius-panel")};background:{C("background-raised")};'
            f'box-shadow:inset 0 0 0 {"1.5px" if strong else "0.5px"} {C("ink-default" if strong else "border-strong")}">'  # Paper ignores tokens in shadow widths
            + head + f'<div style="display:flex;justify-content:center">{visual}</div>' + notes + '</div>')

def card(num, component, question, what, how, changed, options, lean_why, status='open'):
    top = (f'<div style="display:flex;align-items:center;gap:{V("spacing-3")}">' + chip(status)
           + _kicker(f'decision {num:02d} · {component}') + '</div>'
           + f'<div style="font-family:{V("font-display")};font-size:{V("text-2xl")};letter-spacing:{V("tracking-title")};line-height:{V("leading-tight")};color:{C("text-primary")}">{question}</div>')
    blk = lambda k, b: f'<div style="flex:1;display:flex;flex-direction:column;gap:{V("spacing-1")}">' + _kicker(k) + _t(b, 'text-md', 'text-secondary') + '</div>'
    brief = (f'<div layer-name="context" style="display:flex;gap:{V("spacing-8")}">'
             + blk('what it is', what) + blk('how it works', how) + blk('what changed', changed) + '</div>')
    opts = f'<div layer-name="options" style="display:flex;gap:{V("spacing-5")};align-items:stretch">' + ''.join(options) + '</div>'
    foot = (f'<div layer-name="answer" style="display:flex;flex-direction:column;gap:{V("spacing-1")};padding:{V("spacing-4")} {V("spacing-5")};border-radius:{V("radius-panel")};background:{C("surface-wash")}">'
            + _t('my lean · ' + lean_why, 'text-md', 'text-primary') + _t('to answer: comment the letter on this card, or on the option itself', 'text-sm', 'text-label', 'font-label') + '</div>')
    return (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-6")};padding:{V("spacing-10")};width:100%">'
            + f'<div style="display:flex;flex-direction:column;gap:{V("spacing-2")}">{top}</div>' + brief + opts + foot + '</div>')
