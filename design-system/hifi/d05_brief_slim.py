# Decision 05 · brief card, scrolled: the anchored brief compacts when you scroll the Journal thread up (JR-1 mid-fi:
# "the brief compacts to a slim bar that keeps play"). New part, so it goes to 02b as one decision card before JR-1 uses it.
import importlib.util
from review import V, C
from review2 import card, option, _t
def load(n):
    spec = importlib.util.spec_from_file_location(n, f'{n}.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
b, t = load('p03_briefcard'), load('p06_topbar')
MESH = (f'background-color:{C("paper-150")};background-image:radial-gradient(circle farthest-corner at 88% 0% in oklab, {C("amber-200")} 0%, transparent 62%), '
        f'radial-gradient(circle farthest-corner at 0% 100% in oklab, {C("paper-300")} 0%, transparent 75%)')
RAISED = b.RAISED
# the thread passing under the chrome, blurred and fading (the same progressive edge as the tab bar and top bar)
UNDER = (f'<div layer-name="thread under" style="position:absolute;left:0;right:0;top:150px;padding:0 {V("spacing-6")};display:flex;flex-direction:column;gap:{V("spacing-6")}">'
         + _t("third monday like that. what's different about mondays?", 'text-body', 'text-primary', extra=f'letter-spacing:{V("tracking-card")};max-width:300px')
         + f'<div style="align-self:flex-end;max-width:250px;padding:{V("spacing-3")} {V("spacing-4")};border-radius:{V("radius-message")} {V("radius-message")} {V("spacing-size-border-inset")} {V("radius-message")};background:{C("message-mine")}">'
         + _t("i think it's the 9am standup. i dread it.", 'text-body', 'text-primary', extra=f'letter-spacing:{V("tracking-card")}') + '</div></div>'
         + f'<div layer-name="edge" style="position:absolute;left:0;right:0;top:0;height:170px;background:linear-gradient(180deg, {C("background-canvas")} 70%, transparent 100%)"></div>')
def phone(chrome, name):
    return (f'<div layer-name="{name}" style="width:402px;height:300px;position:relative;overflow:clip;background:{C("background-canvas")};'
            f'border-radius:{V("radius-sheet")} {V("radius-sheet")} 0 0;box-shadow:inset 0 0 0 1px {C("border-subtle")}">{UNDER}'
            f'<div layer-name="chrome" style="position:absolute;left:0;top:0;width:402px">{t.STATUS}{chrome}</div></div>')
COLLAPSED = t.bar(t.drawer_button(False) + t.small_label + t.SPACER, 'label')   # the approved collapsed top bar
# A · slim raised bar under the collapsed top bar: thumb of the artwork, the headline on one line, the lit play (smaller)
slim = (f'<div style="padding:{V("spacing-2")} {V("spacing-screen-margin")} 0"><div layer-name="c:brief-card/slim/rest" style="display:flex;align-items:center;gap:{V("spacing-3")};'
        f'padding:{V("spacing-2")} {V("spacing-2")} {V("spacing-2")} {V("spacing-2")};border-radius:{V("radius-panel")};{RAISED}">'
        f'<div layer-name="artwork · thumb" style="width:40px;height:40px;flex-shrink:0;border-radius:{V("radius-default")};{MESH}"></div>'
        f'<div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:{V("spacing-size-border-ring")}">'
        + _t("three things moved since yesterday", 'text-md', 'text-primary', 'font-display-inky', 'font-weight-ink-card', 'white-space:nowrap;overflow:hidden;text-overflow:ellipsis')
        + _t("today's brief · 2 min", 'text-sm', 'text-label', 'font-label') + f'</div>{b.lit_play(36, 16)}</div></div>')
A = phone(COLLAPSED + slim, 'A · slim bar')
# B · no separate bar: the collapsed top bar's trailing slot becomes a small lit "brief" play pill
pill = (f'<div layer-name="c:button/lit/brief-pill" style="height:32px;flex-shrink:0;display:flex;align-items:center;gap:{V("spacing-1")};padding:0 {V("spacing-3")} 0 {V("spacing-2")};border-radius:{V("radius-control")};'
        f'background:linear-gradient(180deg, {C("glow-primary-gradient-top")}, {C("glow-primary-gradient-bottom")});'
        f'box-shadow:inset 0 1px 0 {C("glow-primary-rim")}, inset 0 -1px 1.5px {C("glow-primary-edge")}, 0 0 0 1.5px {C("glow-primary-ring")}, 0 2px 2px {C("glow-primary-cast")}">'
        + b.icon('play', 14, C('glow-primary-foreground'))
        + _t('brief', 'text-sm', 'glow-primary-foreground', 'font-label', 'font-weight-medium') + '</div>')
B = phone(t.bar(t.drawer_button(False) + t.small_label + f'<div style="width:72px;display:flex;justify-content:flex-end">{pill}</div>', 'label'), 'B · play in the top bar')
HTML = card(5, 'brief card · scrolled',
    'when you scroll up the thread, what does the brief become?',
    'the brief card is anchored at the top of Journal. scroll up to older messages and a 272-tall card would cover a third of the screen.',
    'it compacts the moment the thread moves (spring, 300ms) and opens back to full when you return to the bottom or tap it. play keeps working the whole time.',
    'new part: the mid-fi only said "compacts to a slim bar that keeps play". the top bar already collapses to the small centred name, so the two have to sit together.',
    [option('A', 'slim bar under the top bar', A, 'still reads as today\'s brief (artwork, headline); tap anywhere opens the full card', 'costs 56 more of the screen than B', ('lean',)),
     option('B', 'play pill in the top bar', B, 'takes no extra room; the thread gets the whole screen', 'loses the headline: a lit "brief" pill with no context; you have to remember what it plays', ())],
    'A. it keeps the brief recognisable (its artwork and words), so the one lit play is never a mystery button. B saves room but strips the context the card exists to give.')
HTML = HTML.replace('width:440px;flex-shrink:0', 'width:462px;flex-shrink:0')
HTML = HTML.replace(' clip-rule="evenodd" style="opacity: .35" ', ' fill-opacity="0.35" ').replace(' style="opacity: .35" ', ' fill-opacity="0.35" ').replace(' clip-rule="evenodd" ', ' ')
open('d05_brief_slim.html', 'w').write(HTML)
