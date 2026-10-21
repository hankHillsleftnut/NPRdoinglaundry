from blocks import *
from brands import LOGO
from onboarding import col, head, M

def row(name, purpose, trail, logo=True):
    return (f'<div layer-name="row · {name}" style="display:flex;align-items:center;gap:{V("spacing-3")};min-height:{V("spacing-size-row-default")};padding:{V("spacing-2")} 0;border-bottom:{V("spacing-size-border-hairline")} solid {C("border-subtle")}">'
            + (LOGO[name] if logo else '')
            + col(text(name, 'text-body', 'text-primary', 'font-weight-medium', 'leading-snug') + text(purpose, 'text-md', 'text-secondary', lead='leading-snug'), 'spacing-1', 'flex:1')
            + trail + '</div>')
def state(word, colour='accent-text'): return text(word, 'text-md', colour, lead='leading-snug', extra='flex-shrink:0')
def group(label, rows): return col(text(label, 'text-md', 'text-label', 'font-weight-medium', 'leading-snug') + f'<div>{"".join(rows)}</div>', 'spacing-2')

# ON-7 · more sources: everything else, grouped, each with its real state and how
on7 = screen(head(0.55, 'more sources'),
  f'<div layer-name="groups" style="flex-grow:1;display:flex;flex-direction:column;gap:{V("spacing-8")};padding:{V("spacing-6")} {M} {V("spacing-10")}">'
  + col(ink('everything else i can read.') + text('each one says what it adds. files you already have take a minute to export; i walk you through it.', 'text-body', 'text-secondary'), 'spacing-3')
  + group('your accounts', [row('youtube', 'what you watch and save', state('connect')),
      row('tiktok', 'what holds your attention', state('waiting on tiktok', 'text-tertiary')),
      row('x', 'who and what you follow', state('waiting on x', 'text-tertiary')),
      row('linkedin', 'your work, as others see it', state('waiting on linkedin', 'text-tertiary'))])
  + group('files you already have', [row('chatgpt', 'what you’ve been asking an ai', state('how ›')),
      row('claude', 'what you’ve been asking an ai', state('how ›')),
      row('grok', 'what you’ve been asking an ai', state('how ›')),
      row('netflix', 'what you watch to unwind', state('how ›'))])
  + group('your public profiles · optional', [row('instagram', 'how you show up in public', state('add handle')),
      row('substack', 'what you write for others', state('add handle'))])
  + '</div>',
  voice_composer('listening', words_line='your turn · or say "that\'s enough"'))

# ON-8 · where you're headed: aspiration questions, one per screen
on8 = screen(head(0.66, 'where you’re headed'),
  f'<div layer-name="the question" style="flex-grow:1;display:flex;flex-direction:column;gap:{V("spacing-6")};padding:{V("spacing-8")} {M} 0">'
  + ink('if this year went really well, what would be different?') + '</div>',
  voice_composer('speaking'))

# ON-9 · how straight: its recommendation first, with the reason; the other levels as quieter options
on9 = screen(head(0.76, 'how straight'), open('ON-9.choice.html').read(), voice_composer('listening'))

# ON-10 · getting ready: the conversation carries on while the episode is made; the real stage, no percentage
def stage(t, done=False, now=False):
    mark_ = icon('check', 14, 'source-connected') if done else (f'<div style="width:14px;height:14px;flex-shrink:0;border-radius:{V("radius-control")};box-shadow:inset 0 0 0 1.5px {C("accent-default" if now else "border-control")}"></div>')
    return f'<div style="display:flex;align-items:center;gap:{V("spacing-2")}">' + mark_ + text(t, 'text-md', 'text-primary' if now else ('text-label' if done else 'text-tertiary'), lead='leading-snug') + '</div>'
on10 = screen(head(0.88, 'your first episode'),
  f'<div layer-name="making" style="flex-shrink:0;margin:{V("spacing-4")} {M} 0;padding:{V("spacing-3")} {V("spacing-4")};border-radius:{V("radius-panel")};background:{C("surface-wash")};display:flex;flex-direction:column;gap:{V("spacing-2")}">'
  + stage('reading your calendar and health', done=True) + stage('writing your episode', now=True) + stage('recording the voice') + '</div>',
  f'<div layer-name="the question" style="flex-grow:1;display:flex;flex-direction:column;gap:{V("spacing-3")};padding:{V("spacing-8")} {M} 0">'
  + ink('one more while i put it together: who do you call when things go well?') + '</div>',
  voice_composer('listening'))

for name, html in [('ON-7', on7), ('ON-8', on8), ('ON-9', on9), ('ON-10', on10)]:
    open(f'{name}.html', 'w').write(html.replace('\n', ''))
