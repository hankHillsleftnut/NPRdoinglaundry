# Decision cards 02 (settings icons, founder c-k3espe) and 03 (syncing dot colour), round 3, 20 Oct.
import importlib.util
from review import V, C
from review2 import card, option
def load(n):
    spec = importlib.util.spec_from_file_location(n, f'{n}.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
s, l = load('p26_settings_rows'), load('p21_labels')
def slice_(inner):
    return (f'<div style="width:390px;padding:{V("spacing-4")} 0;background:{C("background-canvas")};border-radius:{V("radius-panel")};'
            f'box-shadow:inset 0 0 0 0.5px {C("border-subtle")};display:flex;flex-direction:column;gap:{V("spacing-6")}">{inner}</div>')
chev = s.glyph('chevron-right', 16, C('icon-muted'))
def val(v): return f'<div style="display:flex;align-items:center;gap:{V("spacing-1")};flex-shrink:0">' + s.txt(v, 'text-md', 'text-secondary') + chev + '</div>'
def bare(n): return f'<div style="width:{V("spacing-size-icon-default")};display:flex;flex-shrink:0">{s.glyph(n, 20, C("icon-muted"))}</div>'
def row(lead, title, value=None): return s.row('value', lead + s.words(title, None) + (val(value) if value else chev))
def group(label, rows, icon=True):
    out = []
    for i, r in enumerate(rows):
        out.append(r)
        if i < len(rows) - 1: out.append(s.hairline(icon))
    return (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-1")}"><div style="padding:0 {V("spacing-screen-margin")}">{l.lab("section", label)}</div>' + s.stack(*out) + '</div>')
ITEMS = [('listening', [('mic', 'voice', 'warm'), ('keyboard', 'talk or read', 'talk')]),
         ('', [('lock', 'privacy', None), ('you', 'account', None)])]
def page(lead):
    return slice_(''.join(group(g, [row(lead(i), t, v) for i, t, v in rs]) if g else s.stack(*sum([[row(lead(i), t, v), s.hairline(True)] for i, t, v in rs], [])[:-1]) for g, rs in ITEMS))
A = page(s.well)
B = page(bare)
NONE = slice_(''.join(group(g, [s.row('value', s.words(t, None) + (val(v) if v else chev)) for i, t, v in rs], False) if g else
                      s.stack(*sum([[s.row('value', s.words(t, None) + chev), s.hairline()] for i, t, v in rs], [])[:-1]) for g, rs in ITEMS))
CARD2 = card(2, 'part 22 · settings page', 'how should icons work on the settings page?',
  'the settings page you open from your picture on the you tab: what retro sounds like, what it can see, your data, your account.',
  'each row is one setting; its icon helps you find it at a glance before you read the words.',
  'you said "not a bad settings page, but i want better use of icons". today only the source rows have icons (C). A and B add one to every row.',
  [option('A', 'icon in a soft square', A, 'matches the source rows exactly, so the whole page reads as one system; easy to scan', 'busier; needs a glyph for every setting (help has none yet, i would draw it)', ('lean',)),
   option('B', 'bare icons', B, 'lighter, more editorial; still scannable', 'icons float without the square; source rows would then differ from the rest'),
   option('C', 'words only', NONE, 'calmest; nothing to draw', 'what you said you don’t want: hard to scan', ('current',))],
  'A. one icon language on the whole page (the same square the sources already use), in ink, no colour: rows become findable without getting loud.')
src = lambda dot: s.stack(s.row('source', s.well('brief') + s.words('health', 'how you slept, how you moved') + s.status('syncing', dot)))
GREY = src('icon-muted')
BLUE = src('source-syncing')
CARD3 = card(3, 'part 26 · source rows', 'what colour is the "syncing" dot?',
  'the small dot beside a source’s status on the settings page: green = connected, red = needs you, and this one = syncing.',
  'syncing means retro is pulling in new data right now and will finish on its own. nothing for you to do.',
  'nothing yet: it is blue today because the token was set before your blue rule (blue = the one main action, listening, links, search words).',
  [option('A', 'grey', GREY, 'blue stays rare and meaningful; red still stands out as the only status that wants you', 'syncing is a little easier to miss (the word still says it)', ('lean',)),
   option('B', 'blue', BLUE, 'easier to spot that something is happening', 'blue starts to mean "something’s going on", not just "act here"; breaks the blue rule', ('current',))],
  'A, grey. nothing to do means nothing to notice; the word "syncing" carries it.')
open('decision02.html', 'w').write(CARD2); open('decision03.html', 'w').write(CARD3)

def split(name, num, comp, q, what, how, changed, opts, lean):
    open(f'{name}_shell.html', 'w').write(card(num, comp, q, what, how, changed, [], lean))
    open(f'{name}_options.txt', 'w').write('\n@@@\n'.join(opts))
