# Part 24 · "what i took from this" (founder c-qucagd: "this feels a bit off as a component"): three ways to show what retro
# took from an entry, on the new decision board.
import importlib.util
from review import V, C
from review2 import card, option
def load(n):
    spec = importlib.util.spec_from_file_location(n, f'{n}.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
e, s = load('p24_entry'), load('p26_settings_rows')
def slice_(inner):  # a 390-wide strip of the real page: canvas, screen margins
    return (f'<div style="width:390px;padding:{V("spacing-5")} {V("spacing-screen-margin")};background:{C("background-canvas")};border-radius:{V("radius-panel")};'
            f'box-shadow:inset 0 0 0 0.5px {C("border-subtle")};display:flex;flex-direction:column;gap:{V("spacing-2")}">{inner}</div>')
CLAIMS = ['the monday standup is hard for you', 'you feel dread before 9am meetings', 'you sleep worse on sunday nights']
lab = e.tx('what i took from this', 'text-sm', 'text-label', fam='font-label', w='font-weight-medium')
A = slice_(lab + e.took(CLAIMS[0]) + e.took(CLAIMS[1], 'noted') + e.took(CLAIMS[2]))
def nr_text():
    return (f'<div layer-name="c:button/text-quiet/rest" style="min-height:44px;display:flex;align-items:center;gap:{V("spacing-1")};flex-shrink:0">'
            + e.glyph('correct', 16, C('icon-muted')) + e.tx('not right', 'text-md', 'text-secondary', fam='font-label', w='font-weight-medium', extra='white-space:nowrap') + '</div>')
def b_row(c, noted=False):
    right = (f'<div style="min-height:44px;display:flex;align-items:center;gap:{V("spacing-1")};flex-shrink:0">' + e.glyph('check', 14, C('icon-muted'))
             + e.tx('noted', 'text-md', 'text-label', fam='font-label') + '</div>') if noted else nr_text()
    words = e.tx(c, 'text-body', 'text-tertiary' if noted else 'text-primary', extra=f'flex:1;letter-spacing:{V("tracking-card")}' + (';text-decoration:line-through' if noted else ''))
    return f'<div layer-name="c:took-row/line/{"noted" if noted else "rest"}" style="display:flex;align-items:center;gap:{V("spacing-3")};padding:{V("spacing-1")} 0">' + words + right + '</div>'
hl = f'<div style="height:{V("spacing-size-border-hairline")};background:{C("border-strong")}"></div>'
B = slice_(lab + b_row(CLAIMS[0]) + hl + b_row(CLAIMS[1], True) + hl + b_row(CLAIMS[2]))
quote = lambda c: (f'<div style="display:flex;gap:{V("spacing-3")}"><div style="width:{V("spacing-size-border-ring")};border-radius:{V("radius-control")};background:{C("border-strong")};flex-shrink:0"></div>'
                   + e.tx(c, 'text-body', 'text-primary', extra=f'letter-spacing:{V("tracking-card")}') + '</div>')
C_ = slice_(lab + f'<div style="display:flex;flex-direction:column;gap:{V("spacing-3")};padding:{V("spacing-1")} 0">' + ''.join(quote(c) for c in CLAIMS) + '</div>'
            + f'<div style="display:flex">{nr_text().replace("not right", "something here isn’t right")}</div>')
HTML = card(1, 'part 24 · entry page', 'how should "what i took from this" look?',
  'the list on an entry page of what retro learned from that one entry. it sits under your words, above delete.',
  'each line is one thing retro now believes about you because of this entry. if one is wrong you correct it right there, and retro stops using it.',
  'you said the current version "feels a bit off as a component" (that is A). B and C are new.',
  [option('A', 'cards with a pill', A, 'the fix is unmissable on every line', 'grey pill on a grey card reads like a stack of buttons; long claims squeeze against the pill', ('current',)),
   option('B', 'plain lines, quiet action', B, 'reads as what retro took, in its own words; the fix stays on each line as quiet text', 'the action is less loud; hairlines add a little structure', ('lean',)),
   option('C', 'quoted notes, one action', C_, 'the calmest: reads like retro’s notes on your entry', 'fixing one means a second step (tap, then pick which line)')],
  'B. what retro took is content, not controls, so it should read like text; "not right" stays on every line, one tap away.')
open('p24_took_board.html', 'w').write(HTML)
