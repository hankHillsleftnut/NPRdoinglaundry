# Mid-fi building blocks: grey boxes and real words. Purpose and structure only; no polish.
def V(n): return f"var(--{n})"
def C(n): return V("color-" + n)
def t(s, size='text-body', colour='text-primary', weight='font-weight-regular', extra=''):
    return f'<div style="font-family:{V("font-text")};font-size:{V(size)};font-weight:{V(weight)};line-height:{V("leading-snug")};color:{C(colour)};{extra}">{s}</div>'
def title(s, extra=''):
    return f'<div style="font-family:{V("font-display")};font-size:{V("text-2xl")};line-height:{V("leading-tight")};color:{C("text-primary")};{extra}">{s}</div>'
def lab(s):  # the component a region needs
    return f'<div style="font-family:{V("font-mono")};font-size:{V("text-xs")};line-height:{V("leading-snug")};color:{C("text-label")}">{s}</div>'
def box(label, h=None, inner='', grow=False, extra=''):
    hh = f'height:{h}px;' if h else ''
    return (f'<div style="{hh}{"flex-grow:1;" if grow else ""}border-radius:{V("radius-default")};background:{C("surface-control")};padding:{V("spacing-3")};display:flex;flex-direction:column;gap:{V("spacing-2")};{extra}">'
            + lab(label) + inner + '</div>')
def raised(label, h=None):  # the one pick: lifted off the page (canvas, hairline, soft shadow), never tinted
    hh = f'height:{h}px;' if h else ''
    return f'<div style="{hh}border-radius:{V("radius-default")};background:{C("background-canvas")};box-shadow:0 1px 3px {C("depth-shadow-cast")}, inset 0 0 0 1px {C("border-strong")};padding:{V("spacing-4")}">' + lab(label) + '</div>'
def row(*items, gap='spacing-2', extra=''):
    return f'<div style="display:flex;gap:{V(gap)};{extra}">{"".join(items)}</div>'
def col(*items, gap='spacing-3', extra=''):
    return f'<div style="display:flex;flex-direction:column;gap:{V(gap)};{extra}">{"".join(items)}</div>'
def top(label='', back=True, progress=None):
    p = ''
    if progress is not None:
        p = (f'<div style="height:{V("spacing-size-progress")};border-radius:{V("radius-control")};background:{C("surface-track")};overflow:hidden">'
             f'<div style="width:{int(progress*100)}%;height:100%;background:{C("text-secondary")}"></div></div>')
    nav = '' if not (back or label) else row(t('←' if back else '', 'text-body', 'text-secondary', extra='width:24px'), t(label, 'text-md', 'text-label', extra='flex:1;text-align:center'), t('', extra='width:24px'))
    return col(t('9:41', 'text-md', 'text-secondary'), p, nav, gap='spacing-2')
def composer(state='listening…', anchor=True):
    return box('voice composer (pill)', None, row(t(state, 'text-body', 'text-tertiary', extra='flex:1'), t('◎ mute', 'text-sm', 'text-label')), extra='margin-top:auto' if anchor else '')
def pill(s, lit=False, align='flex-start'):  # a chip or neutral pill: a frame with its label
    raised = f'background:{C("background-canvas")};box-shadow:0 1px 3px {C("depth-shadow-cast")}, inset 0 0 0 1px {C("border-strong")};' if lit else f'background:{C("surface-control")};'
    return (f'<div style="height:36px;align-self:{align};border-radius:{V("radius-control")};{raised}padding:0 {V("spacing-4")};display:flex;align-items:center">'
            + t(s, 'text-md', 'text-primary' if lit else 'text-secondary') + '</div>')
def scroll(*items, gap='spacing-3'):  # content that scrolls under the bottom zone; the next item peeks under a progressive blur
    return col(*items, box('↓ next item peeks here, under the progressive blur', 40, extra='opacity:var(--opacity-disabled)'), gap=gap, extra='flex-grow:1;flex-shrink:1;min-height:0;overflow:hidden')
def bottom(*items, gap='spacing-3'):  # the fixed bottom zone: actions where the thumb is
    return col(*items, gap=gap, extra='margin-top:auto')
def tabbar(sel):
    return box('tab bar', None, row(*[t(('● ' if x == sel else '') + x, 'text-sm', 'text-primary' if x == sel else 'text-label', extra='flex:1;text-align:center') for x in ['journal', 'podcasts', 'goals', 'you']]))
def phone(*content):
    return (f'<div layer-name="phone" style="width:390px;height:844px;flex-shrink:0;box-sizing:border-box;padding:{V("spacing-4")} {V("spacing-6")} {V("spacing-8")};'
            f'display:flex;flex-direction:column;gap:{V("spacing-6")};background:{C("background-canvas")};border-radius:{V("radius-sheet")};box-shadow:inset 0 0 0 1px {C("border-strong")};overflow:hidden">'
            + ''.join(content) + '</div>')
def state_chip(name, what):
    return (f'<div style="flex:1 1 170px;box-sizing:border-box;border-radius:{V("radius-default")};padding:{V("spacing-2")} {V("spacing-3")};box-shadow:inset 0 0 0 1px {C("border-strong")}">'
            + t(name, 'text-sm', 'text-primary', 'font-weight-semibold') + t(what, 'text-sm', 'text-secondary') + '</div>')
def notes(code, purpose, why, components, states, ledger):
    line = lambda k, xs: t(f'{k} ' + ' · '.join(xs), 'text-md', 'text-secondary')
    return (f'<div layer-name="notes" style="width:390px;box-sizing:border-box;padding:{V("spacing-4")} {V("spacing-2")};display:flex;flex-direction:column;gap:{V("spacing-3")}">'
            + t(code, 'text-md', 'text-label', 'font-weight-semibold') + t(purpose, 'text-lg', 'text-primary', 'font-weight-medium')
            + t('why this solution: ' + why, 'text-md', 'text-primary')
            + line('needs:', components)
            + t('states: ' + ' · '.join(f'{n} ({w})' for n, w in states), 'text-md', 'text-secondary')
            + line('ledger + goals doc:', ledger) + '</div>')
def screen(code, purpose, why, components, states, ledger, *content):
    return (f'<div layer-name="{code}" style="display:flex;flex-direction:column;gap:{V("spacing-4")}">' + phone(*content) + notes(code, purpose, why, components, states, ledger) + '</div>')
# Journal: a conversation with Retro under an anchored brief
def jtop(label='journal'):  # all-journals button leading (opens the drawer), page label centred
    btn = f'<div style="width:36px;height:36px;border-radius:{V("radius-control")};background:{C("surface-control")};display:flex;align-items:center;justify-content:center">' + t('☰', 'text-body', 'text-secondary') + '</div>'
    return col(t('9:41', 'text-md', 'text-secondary'),
               row(btn, t(label, 'text-md', 'text-label', extra='flex:1;text-align:center;align-self:center'), t('', extra='width:36px')), gap='spacing-3')
def brief_anchor(label="today's brief · 4 min · ▶ (lit) · leads with what you sent, each item with why · anchored while the thread scrolls under it", h=96):
    return box(label, h)
def mine(s, status=None):  # your message: a raised bubble on the trailing side; the state shows on your latest message only
    bubble = f'<div style="max-width:270px;align-self:flex-end;border-radius:{V("radius-default")};background:{C("surface-control")};padding:{V("spacing-3")} {V("spacing-4")}">' + t(s, 'text-body', 'text-primary') + '</div>'
    return col(bubble, t(status, 'text-sm', 'text-label', extra='align-self:flex-end'), gap='spacing-1') if status else col(bubble, extra='align-self:stretch')
def retro(s):  # Retro's reply: unboxed, leading side, inky
    return f'<div style="max-width:310px;font-family:{V("font-display")};font-size:{V("text-lg")};line-height:{V("leading-snug")};color:{C("text-primary")}">{s}</div>'
def voice_mine(dur, words, status=None):  # a voice message: play, length, and the start of what you said
    b = (f'<div style="width:270px;align-self:flex-end;box-sizing:border-box;border-radius:{V("radius-default")};background:{C("surface-control")};padding:{V("spacing-3")} {V("spacing-4")};display:flex;flex-direction:column;gap:{V("spacing-1")}">'
         + row(t('▶', 'text-body', 'text-secondary'), t(dur, 'text-sm', 'text-label'), gap='spacing-2') + t(words, 'text-md', 'text-secondary') + '</div>')
    return col(b, t(status, 'text-sm', 'text-label', extra='align-self:flex-end'), gap='spacing-1') if status else col(b)
def because(s):  # what a guess or observation rests on, under Retro's reply
    return t(s, 'text-sm', 'text-link')
def recap(s):  # a finished conversation as one card in the thread (your onboarding)
    return f'<div style="border-radius:{V("radius-default")};background:{C("surface-control")};padding:{V("spacing-4")};display:flex;flex-direction:column;gap:{V("spacing-1")}">' + s + '</div>'
def day(s):
    return t(s, 'text-sm', 'text-label', extra='text-align:center')
def thread(*items):  # scrolls under the anchored brief; newest at the bottom
    fade = f'<div layer-name="progressive blur (under the brief)" style="position:absolute;top:0;left:0;right:0;height:40px;background:{C("background-canvas")};opacity:var(--opacity-pressed)"></div>'
    return col(*items, fade, gap='spacing-10', extra='position:relative;flex-grow:1;flex-shrink:1;min-height:0;justify-content:flex-end;overflow:hidden')
def exchange(label, *items):  # one day: its label 8 above, then the messages 24 apart (space.betweenEntries)
    return col(day(label), col(*items, gap='spacing-6'), gap='spacing-2')
