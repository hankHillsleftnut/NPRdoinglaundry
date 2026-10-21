# Part 41 · "why this is here" (PC-3): the claim one part of an episode makes, and the evidence it rests on.
# Pushed inside the player sheet (sheets never stack). The claim is inky; stated vs asked follows guess-card.md (asked looks unfinished:
# dashed, no shadow). Evidence is a grouped list on a wash, each row: a 32 kind well (decision 02), date, what, open ›.
import importlib.util, json
from review import V, C
from review2 import _t
I = json.load(open('../icons/outlined-20.json'))
def g(n, px, c): return f'<svg layer-name="c:icon/{n}" width="{px}" height="{px}" viewBox="0 0 24 24" style="flex-shrink:0"><path fill="{c}" fill-rule="evenodd" d="{I[n]}"/></svg>'
def well(n): return (f'<div layer-name="well" style="width:32px;height:32px;flex-shrink:0;border-radius:{V("radius-default")};background:{C("surface-wash")};'
                     f'display:flex;align-items:center;justify-content:center">{g(n, 18, C("icon-default"))}</div>')
def row(kind, date, what, last=False):
    hair = '' if last else f'box-shadow:inset 0 -1px 0 {C("border-subtle")};'  # founder 20 Oct (c-7iso8b): a firmer 1pt line between rows
    return (f'<div layer-name="c:evidence-row/rest" style="min-height:{V("spacing-size-row-default")};display:flex;align-items:center;gap:{V("spacing-3")};padding:{V("spacing-3")} {V("spacing-4")};{hair}">'
            + well(kind) + f'<div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:{V("spacing-size-border-ring")}">'
            + _t(date, 'text-sm', 'text-label', 'font-label') + _t(what, 'text-md', 'text-primary', extra=f'letter-spacing:{V("tracking-card")};white-space:nowrap;overflow:hidden;text-overflow:ellipsis') + '</div>'  # one line, never two (c-7iso8b)
            + g('chevron-right', 14, C('icon-muted')) + '</div>')
ROWS = [('journal', '14 oct · your words', 'up at 6:40, a long focused morning'),
        ('journal', '16 oct · your words', '"felt sharp before anyone was online"'),
        ('calendar', '17 oct · calendar', 'ran at 7, then shipped the deck')]
def rows(): return (f'<div layer-name="evidence list" style="display:flex;flex-direction:column;border-radius:{V("radius-panel")};background:{C("background-canvas")};'
                    f'box-shadow:0 0 0 0.5px {C("depth-stroke-outer")}">' + ''.join(row(*r, last=i == len(ROWS) - 1) for i, r in enumerate(ROWS)) + '</div>')
def claim(state='stated'):
    if state == 'stated':
        return (f'<div layer-name="c:claim/stated" style="display:flex;flex-direction:column;gap:{V("spacing-2")}">'
                + f'<div style="font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-title")};font-size:{V("text-3xl")};line-height:{V("leading-tight")};letter-spacing:{V("tracking-title")};color:{C("text-primary")};text-wrap:balance">your best days start early.</div>'
                + _t('stated · from what you did · very sure', 'text-sm', 'text-label', 'font-label') + '</div>')
    return (f'<div layer-name="c:claim/asked" style="display:flex;flex-direction:column;gap:{V("spacing-2")};padding:{V("spacing-4")};border-radius:{V("radius-card")};'
            f'background:{C("inference-surface")};outline:1px dashed {C("inference-border")};outline-offset:-1px">'
            + _t('a guess', 'text-sm', 'text-label', 'font-label', 'font-weight-medium')
            + f'<div style="font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-card")};font-size:{V("text-2xl")};line-height:{V("leading-tight")};letter-spacing:{V("tracking-card")};color:{C("text-primary")};text-wrap:balance">are mornings when you do your best work?</div>'
            + _t('asked · fairly sure · rests on 3 mornings', 'text-sm', 'text-label', 'font-label') + '</div>')
def label(s): return _t(s, 'text-sm', 'text-label', 'font-label', 'font-weight-medium', f'letter-spacing:{V("tracking-label")}')
def page(state):
    return (f'<div layer-name="why · {state}" style="display:flex;flex-direction:column;gap:{V("spacing-8")}">' + claim(state)
            + f'<div style="display:flex;flex-direction:column;gap:{V("spacing-2")}">' + label('what it rests on') + rows() + '</div></div>')
open('p41_stated.html', 'w').write(page('stated'))
open('p41_asked.html', 'w').write(page('asked'))
