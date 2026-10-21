from blocks import *
from brands import LOGO
M = V("spacing-screen-margin")
def col(inner, gap='spacing-4', extra=''):
    return f'<div style="display:flex;flex-direction:column;gap:{V(gap)};{extra}">{inner}</div>'
def head(frac, label='', back=True):
    return status() + progress(frac) + topbar(label, back=back)

# ON-3 · the mission: Retro speaks one line at a time, then asks talk or type
on3 = screen(head(0.08, back=False),
  f'<div layer-name="the moment" style="flex-grow:1;display:flex;flex-direction:column;justify-content:center;align-items:center;gap:{V("spacing-8")};padding:0 {M}">'
  + mark()
  + col(ink('want to talk, or would you rather type?', extra='text-align:center'), 'spacing-3', 'align-items:center;width:326px')
  + segmented(['talk', 'type']) + '</div>',
  voice_composer('listening'))

# ON-4 · your story: one question per screen; you answer by talking, your words appear as you say them
on4 = screen(head(0.2, 'getting to know you'),
  f'<div layer-name="the question" style="flex-grow:1;display:flex;flex-direction:column;gap:{V("spacing-3")};padding:{V("spacing-8")} {M} 0">'
  + ink("what's taking up most of your head lately?") + open('ON-4.words.html').read() + '</div>',
  voice_composer('listening'))

# ON-5 · privacy: a title and a description, nothing else
def item(t, d):
    return col(text(t, 'text-body', 'text-primary', 'font-weight-semibold', 'leading-snug') + text(d, 'text-body', 'text-secondary'), 'spacing-1')
on5 = screen(head(0.38, 'privacy'), open('ON-5.moment.html').read(), voice_composer('speaking'))

# ON-6 · connect: every launch source as a button with its logo; the meter names what Retro can see
SOURCES = [('apple health', 'your sleep and energy', True), ('calendar', 'the shape of your weeks', True),
  ('google', 'mail, docs, calendar, youtube', False), ('contacts', "who's who in what you say", False),
  ('screen time', 'where your attention goes', False), ('photos', 'where you go, and when', False),
  ('spotify', 'your moods, in music', False), ('apple music', 'your moods, in music', False), ('reddit', 'what you follow and ask', False)]
def src_button(name, sees, on):
    trail = (f'<div style="display:flex;align-items:center;gap:{V("spacing-1")}">' + icon('check', 16, 'source-connected') + text('connected', 'text-md', 'status-success-text', lead='leading-snug') + '</div>') if on \
            else text('connect', 'text-md', 'accent-text', 'font-weight-medium', 'leading-snug')
    return (f'<div layer-name="source · {name}" style="flex:1 1 140px;box-sizing:border-box;padding:{V("spacing-4")};border-radius:{V("radius-panel")};background:{C("background-raised")};'
            f'display:flex;flex-direction:column;gap:{V("spacing-3")};'
            f'box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, 0 0 0 0.5px {C("depth-stroke-outer")}, 0 1px 1.5px {C("depth-shadow-contact")}, 0 6px 16px -8px {C("depth-shadow-cast")}">'
            + LOGO[name]
            + col(text(name, 'text-body', 'text-primary', 'font-weight-medium', 'leading-snug') + text(sees, 'text-md', 'text-secondary', lead='leading-snug'), 'spacing-1')
            + trail + '</div>')
def meter():
    segs = ''.join(f'<div style="flex:1;height:8px;border-radius:{V("radius-control")};background:{C("accent-default" if on else "surface-track")}"></div>' for _, _, on in SOURCES)
    return (f'<div layer-name="what retro can see" style="display:flex;flex-direction:column;gap:{V("spacing-3")}">'
            + f'<div style="display:flex;gap:{V("spacing-1")}">{segs}</div>' + '</div>')
grid = f'<div layer-name="sources" style="display:flex;flex-wrap:wrap;gap:{V("spacing-3")}">' + ''.join(src_button(*s) for s in SOURCES) + '</div>'
on6 = screen(head(0.5, 'connect'),
  f'<div layer-name="purpose display" style="display:flex;flex-direction:column;gap:{V("spacing-6")};padding:{V("spacing-8")} {M} 0">'
  + ink("let me see what words can't.")
  + meter() + grid
  + text('more sources and files you already have', 'text-md', 'text-link') + '</div>',
  voice_composer('listening', words_line='your turn · ask me anything about these'))

for name, html in [('ON-3', on3), ('ON-4', on4), ('ON-5', on5), ('ON-6', on6)]:
    open(f'{name}.html', 'w').write(html)
