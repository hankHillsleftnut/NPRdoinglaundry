# Decision card 04 · part 27 · the settings page (ST-1): approve it, and settle how a value row ends (› or ↕).
import importlib.util
from review import V, C
from review2 import card, option
def load(n):
    spec = importlib.util.spec_from_file_location(n, f'{n}.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
s = load('p26_settings_rows')
def slice_(inner):
    return (f'<div style="width:390px;padding:{V("spacing-2")} 0;background:{C("background-canvas")};border-radius:{V("radius-panel")};'
            f'box-shadow:inset 0 0 0 0.5px {C("border-subtle")};display:flex;flex-direction:column">{inner}</div>')
def vrow(t, v, glyph):
    return s.row('value', s.words(t, None) + f'<div style="display:flex;align-items:center;gap:{V("spacing-1")};flex-shrink:0">'
                 + s.txt(v, 'text-md', 'text-secondary') + s.glyph(glyph, 16, C('icon-muted')) + '</div>')
A = slice_(vrow('voice', 'warm', 'chevron-right') + s.hairline() + vrow('daily brief', '8:30 · on', 'chevron-right'))
B = slice_(vrow('voice', 'warm', 'chevron-up-down') + s.hairline() + vrow('daily brief', '8:30 · on', 'chevron-right'))
HTML = card(4, 'part 27 · settings page', 'is the settings page right, and how should a value row end?',
  'the settings page itself (ST-1 from the mid-fi): back, "settings" small and centred, groups named by small grey labels (your call: Geist), every row showing its current value.',
  'tap a row to change it. some rows open a new page (daily brief: time, length, on/off); others just pick from a short list in place (voice: warm, clear, quiet).',
  'new. the whole page is drawn at 1× under the options. the spec says a row that opens a picker ends in ↕; the mid-fi drew › everywhere.',
  [option('A', '› on every row', A, 'one simple rule: everything you tap ends the same way', 'you can’t tell a quick pick from a new page before you tap', ('current', 'lean')),
   option('B', '↕ for a pick, › for a page', B, 'tells you what will happen: ↕ = choose from a list right here, › = go to a page', 'two signs to learn; ↕ is less familiar in settings lists')],
  'A for now: › everywhere is what iOS settings do, and the value beside it already says what you’ll change. if you also approve the page, say "approve 04".')
open('decision04.html', 'w').write(HTML)
