# Part 50 · search (M8, YO-1/YO-2): the field (mic first), the written answer with numbered claims, and the numbered sources.
# Founder's search v1 shape: a short synthesis on top ("what i found"), inspectable sources below, abstains in plain words.
# Every claim carries a number that matches one source row; a guess is labelled in words, never only by colour.
import importlib.util
from review import V, C
from review2 import _t, _kicker
def load(n):
    spec = importlib.util.spec_from_file_location(n, f'{n}.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
b, s26 = load('p03_briefcard'), load('p26_settings_rows')

RING = (f'box-shadow:inset 0 1px 2px {C("depth-shadow-sunken")}, inset 0 0 0 0.5px {C("depth-stroke-outer")}')
def field(text=None):
    mic = (f'<div layer-name="mic" style="width:36px;height:36px;flex-shrink:0;border-radius:{V("radius-control")};background:{C("surface-wash")};'
           f'display:flex;align-items:center;justify-content:center">{b.icon("mic", 18, C("icon-default"))}</div>')
    words = (_t(text, 'text-body', 'text-primary', extra='flex:1;min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis') if text else
             _t('ask anything about yourself', 'text-body', 'text-tertiary', extra='flex:1'))
    clear = (f'<div layer-name="clear" style="width:36px;height:36px;flex-shrink:0;display:flex;align-items:center;justify-content:center">{b.icon("close", 16, C("icon-muted"))}</div>') if text else ''
    return (f'<div layer-name="c:search-field/{"typed" if text else "rest"}" style="width:354px;height:48px;display:flex;align-items:center;gap:{V("spacing-2")};'
            f'padding:0 {V("spacing-1")} 0 {V("spacing-1")};border-radius:{V("radius-control")};background:{C("surface-control")};{RING}">' + mic + words + clear + '</div>')
# Paper flattens inline runs, so the drawing uses superscript numerals; the chip below is the iOS spec (ios-build-notes.md)
def cite(n):  # a claim's number: small, mono, on a wash; it is the tap target that scrolls to its source
    return (f'<span layer-name="c:cite/{n}" style="display:inline-flex;align-items:center;justify-content:center;min-width:18px;height:18px;padding:0 {V("spacing-1")};'
            f'border-radius:{V("radius-control")};background:{C("surface-wash")};font-family:{V("font-mono")};font-size:{V("text-xs")};color:{C("text-secondary")};vertical-align:2px">{n}</span>')
def answer(state='found'):
    if state == 'found':
        body = (f'<div style="font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-card")};font-size:{V("text-xl")};line-height:{V("leading-snug")};'
                f'letter-spacing:{V("tracking-card")};color:{C("text-primary")}">after days you run¹, and when work stops before 9².</div>'
                + f'<div style="font-family:{V("font-text")};font-size:{V("text-body")};line-height:{V("leading-snug")};color:{C("text-secondary")}">'
                  'a guess: weekends help less than you think³.</div>')
    else:  # abstains: it says so plainly, then what the sources do show
        body = (f'<div style="font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-card")};font-size:{V("text-xl")};line-height:{V("leading-snug")};'
                f'letter-spacing:{V("tracking-card")};color:{C("text-primary")}">nothing you\'ve said answers this yet.</div>'
                + _t('the closest: you mentioned your sister twice in october, both about the move.', 'text-body', 'text-secondary'))
    return (f'<div layer-name="c:answer/{state}" style="width:354px;display:flex;flex-direction:column;gap:{V("spacing-2")}">'
            + _kicker('what i found' if state == 'found' else 'what i found') + body + '</div>')
def num(n):
    return (f'<div layer-name="number" style="width:32px;height:32px;flex-shrink:0;border-radius:{V("radius-default")};background:{C("surface-wash")};'
            f'display:flex;align-items:center;justify-content:center;font-family:{V("font-mono")};font-size:{V("text-sm")};color:{C("text-secondary")}">{n}</div>')
def srow(n, kind, what, last=False):
    hair = '' if last else f'box-shadow:inset 0 -1px 0 {C("border-subtle")};'
    return (f'<div layer-name="c:source-result/rest" style="min-height:{V("spacing-size-row-default")};display:flex;align-items:center;gap:{V("spacing-3")};padding:{V("spacing-3")} {V("spacing-4")};{hair}">'
            + num(n) + f'<div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:{V("spacing-size-border-ring")}">'
            + _t(kind, 'text-sm', 'text-label', 'font-label')
            + _t(what, 'text-md', 'text-primary', extra=f'letter-spacing:{V("tracking-card")};white-space:nowrap;overflow:hidden;text-overflow:ellipsis') + '</div>'
            + b.icon('chevron-right', 14, C('icon-muted')) + '</div>')
SOURCES = [(1, 'apple health · 14 nights', 'you slept 40 min longer after a run'), (2, 'journal · 3 entries', '"stopped at 8, slept like a rock"'), (3, 'calendar · 4 weekends', 'no early events, no better sleep')]
def sources():
    return (f'<div layer-name="sources" style="width:354px;display:flex;flex-direction:column;gap:{V("spacing-2")}">' + _kicker('sources')
            + f'<div layer-name="source list" style="display:flex;flex-direction:column;border-radius:{V("radius-panel")};background:{C("background-canvas")};box-shadow:0 0 0 0.5px {C("depth-stroke-outer")}">'
            + ''.join(srow(*x, last=i == 2) for i, x in enumerate(SOURCES)) + '</div></div>')
def certain():
    return (f'<div layer-name="c:settings-row/switch · only certain" style="width:354px;min-height:{V("spacing-size-row-default")};display:flex;align-items:center;gap:{V("spacing-3")};padding:{V("spacing-2")} {V("spacing-4")};'
            f'border-radius:{V("radius-panel")};background:{C("surface-wash")}">'
            + f'<div style="flex:1;display:flex;flex-direction:column;gap:{V("spacing-size-border-ring")}">' + _t("only what's certain", 'text-md', 'text-primary', 'font-text', 'font-weight-medium')
            + _t('hides the 1 guess', 'text-sm', 'text-label', 'font-label') + '</div>' + s26.switch(False) + '</div>')
def tile(inner, cap, why):
    return (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-3")};width:354px">' + inner
            + _t(cap, 'text-md', 'text-primary', 'font-label', 'font-weight-medium') + _t(why, 'text-md', 'text-secondary') + '</div>')
blk = lambda k, s: f'<div style="flex:1;display:flex;flex-direction:column;gap:{V("spacing-1")}">' + _kicker(k) + _t(s, 'text-md', 'text-secondary') + '</div>'
HTML = (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-8")};padding:{V("spacing-10")};width:100%">'
        f'<div layer-name="header" style="display:flex;flex-direction:column;gap:{V("spacing-2")}"><div style="display:flex;align-items:center;gap:{V("spacing-3")}">'
        + _t('approve?', 'text-sm', 'text-inverse', 'font-label', 'font-weight-medium', f'padding:{V("spacing-1")} {V("spacing-3")};border-radius:{V("radius-control")};background:{C("ink-default")}')
        + _t('M8 · part 50 · you', 'text-lg', 'text-primary', 'font-label', 'font-weight-medium')
        + f'<div layer-name="needs you · red dot" style="width:{V("spacing-3")};height:{V("spacing-3")};flex-shrink:0;border-radius:{V("radius-control")};background:{C("status-danger")}"></div></div>'
        + f'<div style="font-family:{V("font-display")};font-size:{V("text-2xl")};letter-spacing:{V("tracking-title")};line-height:{V("leading-tight")};color:{C("text-primary")}">search: an answer from your own mind, with its receipts</div></div>'
        + f'<div layer-name="context" style="display:flex;gap:{V("spacing-8")}">'
        + blk('what it is', 'the field on top of You (mic first: talking is the fastest way to ask), a short written answer, and the sources it rests on, each numbered.')
        + blk('how it works', 'sources arrive first (~1 s), then the answer writes in. every claim has a number; tap it to jump to its source. a guess says "a guess". when nothing answers, it says so and shows the closest thing.')
        + blk('built from', "the composer's sunken field, part 41's evidence rows (a number well instead of a kind well), the inky answer type used for claims, part 25's switch. no lit object: reading, not acting.")
        + '</div>'
        + f'<div layer-name="states" style="display:flex;gap:{V("spacing-10")};align-items:flex-start;flex-wrap:wrap">'
        + tile(field(), 'field · rest', 'the mic leads; the placeholder says what you can ask, in your words.')
        + tile(field('when do i sleep best?'), 'field · typed', 'your question stays in the field above the answer, so you can change it; clear on the right.')
        + tile(answer(), 'answer · found', 'two to five sentences; facts plain and inky, a guess labelled in words and set in body type, so it reads as less sure.')
        + tile(sources(), 'sources', 'numbered to match the claims; one line each (they end with "…"), open › for the whole thing.')
        + tile(certain(), "only what's certain", "one switch hides the guesses and says how many it hid.")
        + tile(answer('abstained'), 'answer · nothing found', 'it abstains in plain words, then shows the closest thing it does know, so the search never dead-ends.')
        + '</div>'
        + f'<div layer-name="answer" style="padding:{V("spacing-4")} {V("spacing-5")};border-radius:{V("radius-panel")};background:{C("surface-wash")}">'
        + _t('to answer: comment "yes" on this card, or the change where you see it', 'text-sm', 'text-label', 'font-label') + '</div></div>')
open('p50_search.html', 'w').write(HTML)
