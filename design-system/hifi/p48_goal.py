# Part 48 · goal card (M7, GL-1/GL-2): one goal in your words, what you said against what you did, one line from retro.
# goal.md: both said and did in words (rule 1), never shame (rule 2: no red, no streaks, no "failed"), you can end it (rule 3).
# A goal retro only heard is a guess, so it wears the guess look (dashed inference border, no shadow) until you say yes.
import importlib.util
from review import V, C
from review2 import _t, _kicker
def load(n):
    spec = importlib.util.spec_from_file_location(n, f'{n}.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
b, pl = load('p03_briefcard'), load('p20_pill')

def track(pct, fill):
    return (f'<div layer-name="track" style="flex:1;min-width:0;height:4px;border-radius:{V("radius-control")};background:{C("surface-track")};overflow:clip">'
            f'<div layer-name="fill" style="width:{pct}%;height:100%;border-radius:{V("radius-control")};background:{C(fill)}"></div></div>')
def sd(word, pct, count, fill, empty=None):
    # the label and the count are fixed slots, so the two tracks line up across every card
    mid = track(pct, fill) if empty is None else _t(empty, 'text-sm', 'text-label', 'font-label', extra='flex:1')
    return (f'<div layer-name="{word}" style="display:flex;align-items:center;gap:{V("spacing-3")}">'
            + _t(word, 'text-xs', 'text-label', 'font-mono', extra=f'width:28px;flex-shrink:0;letter-spacing:{V("tracking-label")}')
            + mid + _t(count, 'text-sm', 'text-secondary', 'font-label', extra='width:64px;flex-shrink:0;text-align:right') + '</div>')
def title(s): return _t(s, 'text-body', 'text-primary', 'font-text', 'font-weight-semibold', f'letter-spacing:{V("tracking-card")};text-wrap:balance')
def card(name, said, did, line, state='rest'):
    bars = (f'<div layer-name="said vs did" style="display:flex;flex-direction:column;gap:{V("spacing-2")}">'
            + sd('said', said[1], said[0], 'goal-said')
            + (sd('did', 0, '', 'goal-did', empty='too early to tell') if state == 'too early' else sd('did', did[1], did[0], 'goal-did')) + '</div>')
    return (f'<div layer-name="c:goal-card/{state}" style="width:354px;display:flex;flex-direction:column;gap:{V("spacing-3")};padding:{V("spacing-4")} {V("spacing-5")} {V("spacing-5")};{b.RAISED}">'
            + title(name) + bars + _t(line, 'text-md', 'text-secondary', extra='text-wrap:balance') + '</div>')
def pill(s):
    t = pl.TIER['raised']
    return (f'<div layer-name="c:pill/raised" style="height:32px;display:flex;align-items:center;padding:0 {V("spacing-4")};border-radius:{V("radius-control")};background:{t["bg"]};box-shadow:{t["shadow"]}">'
            + _t(s, 'text-md', 'text-primary', 'font-text', 'font-weight-semibold') + '</div>')
GUESS = (f'<div layer-name="c:goal-card/guess" style="width:354px;display:flex;flex-direction:column;gap:{V("spacing-3")};padding:{V("spacing-4")} {V("spacing-5")} {V("spacing-5")};'
         f'border-radius:{V("radius-card")};background:{C("inference-surface")};outline:1px dashed {C("inference-border")};outline-offset:-1px">'
         + _t('a guess · a goal?', 'text-sm', 'text-label', 'font-label', 'font-weight-medium')
         + f'<div style="font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-card")};font-size:{V("text-xl")};line-height:{V("leading-tight")};letter-spacing:{V("tracking-card")};color:{C("text-primary")};text-wrap:balance">'
           'you keep saying you want to see your family more. is that a goal?</div>'
         + f'<div style="display:flex;gap:{V("spacing-2")}">' + pill('yes') + pill('not quite') + '</div></div>')
# ended goals: one grouped row below the cards, never a list of failures; revivable inside
FADED = (f'<div layer-name="c:goal-row/faded" style="width:354px;min-height:{V("spacing-size-row-default")};display:flex;align-items:center;gap:{V("spacing-3")};padding:{V("spacing-3")} {V("spacing-4")};'
         f'border-radius:{V("radius-panel")};background:{C("surface-wash")}">'
         + _t('turned off 2 · merged 1', 'text-md', 'text-secondary', extra='flex:1') + b.icon('chevron-right', 14, C('icon-muted')) + '</div>')
REST = card('ship the first version', ('6 times', 80), ('4 hours', 60), 'you work on it most on tuesdays.')
LOW = card('sleep before midnight', ('3 times', 45), ('1 night', 15), 'late nights cluster before demos.')
EARLY = card('run twice a week', ('2 times', 30), None, 'started 9 days ago. i\'ll know more next week.', 'too early')
def tile(inner, cap, why):
    return (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-3")};width:354px">' + inner
            + _t(cap, 'text-md', 'text-primary', 'font-label', 'font-weight-medium') + _t(why, 'text-md', 'text-secondary') + '</div>')
blk = lambda k, s: f'<div style="flex:1;display:flex;flex-direction:column;gap:{V("spacing-1")}">' + _kicker(k) + _t(s, 'text-md', 'text-secondary') + '</div>'
HTML = (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-8")};padding:{V("spacing-10")};width:100%">'
        f'<div layer-name="header" style="display:flex;flex-direction:column;gap:{V("spacing-2")}"><div style="display:flex;align-items:center;gap:{V("spacing-3")}">'
        + _t('approve?', 'text-sm', 'text-inverse', 'font-label', 'font-weight-medium', f'padding:{V("spacing-1")} {V("spacing-3")};border-radius:{V("radius-control")};background:{C("ink-default")}')
        + _t('M7 · part 48 · goals', 'text-lg', 'text-primary', 'font-label', 'font-weight-medium')
        + f'<div layer-name="needs you · red dot" style="width:{V("spacing-3")};height:{V("spacing-3")};flex-shrink:0;border-radius:{V("radius-control")};background:{C("status-danger")}"></div></div>'
        + f'<div style="font-family:{V("font-display")};font-size:{V("text-2xl")};letter-spacing:{V("tracking-title")};line-height:{V("leading-tight")};color:{C("text-primary")}">goal card: what you said against what you did</div></div>'
        + f'<div layer-name="context" style="display:flex;gap:{V("spacing-8")}">'
        + blk('what it is', 'one goal in your words. two quiet bars put how often you talk about it beside the evidence it happened, each with its count in words; one line from retro says what it notices.')
        + blk('how it works', 'tap opens the goal (GL-2). the bars fill once on first view. a goal retro only heard arrives as a dashed guess; ended goals wait in one row below, never as failures.')
        + blk('built from', 'the brief card\'s raised surface, the guess look from guess-card.md (as on PC-3), the raised pill (part 20), goal.said / goal.did and surface.track tokens. no red, no %, no streaks.')
        + '</div>'
        + f'<div layer-name="states" style="display:flex;gap:{V("spacing-10")};align-items:flex-start;flex-wrap:wrap">'
        + tile(REST, 'rest', 'said and did both strong: the bars are close, and the line names when.')
        + tile(LOW, 'a gap', 'the gap is the insight, so it is shown plainly, without colour judging it; the line explains, never scolds.')
        + tile(EARLY, 'too early', 'for the first two weeks, did says "too early to tell" instead of a near-empty bar that would read as failing.')
        + tile(GUESS, 'a guess', 'heard, not stated: dashed until you answer. yes makes it a goal; not quite asks what you meant.')
        + tile(FADED, 'ended', 'turned off and merged goals collapse into one quiet row; inside, each can be turned back on.')
        + '</div>'
        + f'<div layer-name="answer" style="padding:{V("spacing-4")} {V("spacing-5")};border-radius:{V("radius-panel")};background:{C("surface-wash")}">'
        + _t('to answer: comment "yes" on this card, or the change where you see it', 'text-sm', 'text-label', 'font-label') + '</div></div>')
open('p48_goal.html', 'w').write(HTML)
