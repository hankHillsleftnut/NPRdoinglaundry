# YO-5 · what i know about you: its answers to the questions about you, grouped by area of life.
# What moved leads (it's the news); each area is an inky section; each answer row: the question small, the answer plain,
# how sure in a word + four dots (one quiet visual) and from how many things; an area it knows nothing about says so warmly.
from review import V, C
from review2 import _t
import importlib.util
def load(n):
    spec = importlib.util.spec_from_file_location(n, f'{n}.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
b = load('p03_briefcard')
CHEV = b.icon('chevron-right', 14, C('icon-muted'))
def dots(n):
    d = lambda on: f'<div style="width:6px;height:6px;border-radius:{V("radius-control")};background:{C("text-secondary") if on else C("surface-track")}"></div>'
    return f'<div layer-name="how sure · {n} of 4" style="display:flex;gap:{V("spacing-size-border-ring")};align-items:center">' + ''.join(d(i < n) for i in range(4)) + '</div>'
def answer(q, a, word, n, frm, last=False):
    hair = '' if last else f'box-shadow:inset 0 -1px 0 {C("border-subtle")};'
    sure = (f'<div style="display:flex;align-items:center;gap:{V("spacing-2")}">' + _t(word, 'text-sm', 'text-label', 'font-label') + dots(n)
            + _t('· ' + frm, 'text-sm', 'text-label', 'font-label') + '</div>')
    return (f'<div layer-name="c:answer-row/rest" style="display:flex;align-items:center;gap:{V("spacing-3")};padding:{V("spacing-3")} {V("spacing-4")};{hair}">'
            + f'<div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:{V("spacing-1")}">' + _t(q, 'text-sm', 'text-label', 'font-label')
            + _t(a, 'text-body', 'text-primary', extra=f'letter-spacing:{V("tracking-card")};text-wrap:balance') + sure + '</div>' + CHEV + '</div>')
def group(rows): return (f'<div layer-name="answers" style="display:flex;flex-direction:column;border-radius:{V("radius-panel")};background:{C("background-canvas")};'
                         f'box-shadow:0 0 0 0.5px {C("depth-stroke-outer")}">' + ''.join(rows) + '</div>')
def area(name, inner): return (f'<div layer-name="area · {name}" style="display:flex;flex-direction:column;gap:{V("spacing-3")}">'
                               + f'<div style="font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-card")};font-size:{V("text-xl")};line-height:{V("leading-tight")};letter-spacing:{V("tracking-card")};color:{C("text-primary")}">{name}</div>' + inner + '</div>')
moved = (f'<div layer-name="moved this week" style="display:flex;align-items:center;gap:{V("spacing-3")};min-height:{V("spacing-size-row-default")};padding:{V("spacing-2")} {V("spacing-4")};border-radius:{V("radius-panel")};background:{C("surface-wash")}">'
         + f'<div style="flex:1;display:flex;flex-direction:column;gap:{V("spacing-size-border-ring")}">' + _t('moved this week', 'text-md', 'text-primary', 'font-text', 'font-weight-medium')
         + _t('2 answers changed', 'text-sm', 'text-label', 'font-label') + '</div>' + CHEV + '</div>')
quiet = _t("i don't know much about your family yet. tell me about them whenever you like.", 'text-body', 'text-secondary', extra='text-wrap:balance')
CONTENT = (f'<div layer-name="content" style="flex:1 1 0%;min-height:0;display:flex;flex-direction:column;gap:{V("spacing-8")};padding:{V("spacing-2")} {V("spacing-screen-margin")} 0">'
           + f'<div style="font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-title")};font-size:{V("text-3xl")};line-height:{V("leading-tight")};letter-spacing:{V("tracking-title")};color:{C("text-primary")}">what i know about you</div>'
           + moved
           + area('work', group([answer('what drives you most?', 'building things people use.', 'fairly sure', 3, 'from 9 things'),
                                 answer('when do you work best?', 'early, before anyone is online.', 'very sure', 4, 'from 14 things', True)]))
           + area('health', group([answer('what helps you sleep?', 'running, and stopping work before 9.', 'fairly sure', 3, 'from 6 things', True)]))
           + area('family', quiet) + '</div>')
open('p51_known.html', 'w').write(CONTENT)
