# Part 46 · the paywall (ON-12): rises out of the first episode; value first, the decision in the thumb zone.
# Spec (components/paywall.md) and mid-fi disagree on choosing a plan: the spec makes the two plans the buttons (yearly lit),
# the mid-fi selects a plan and then one lit "subscribe". One decision card (06), both drawn as full phones.
# Prices are the founder's (#20: $19.99 a month, $199.99 a year, no trial) shown as examples; the app reads them from StoreKit.
import importlib.util, re
from review import V, C
from review2 import card, option, _t
def load(n):
    spec = importlib.util.spec_from_file_location(n, f'{n}.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
b, t, e = load('p03_briefcard'), load('p06_topbar'), load('p40_episode_tiles')
SHADOW_RAISED = (f'box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, 0 0 0 0.5px {C("depth-stroke-outer")}, 0 1px 1.5px {C("depth-shadow-contact")}, '
                 f'0 4px 10px -4px {C("depth-shadow-cast")}, 0 10px 30px -10px {C("depth-shadow-ambient")}')
LIT = (f'background:linear-gradient(180deg, {C("glow-primary-gradient-top")}, {C("glow-primary-gradient-bottom")});'
       f'box-shadow:inset 0 1px 0 {C("glow-primary-rim")}, inset 0 -1px 1.5px {C("glow-primary-edge")}, inset 0 0 6px {C("glow-primary-bloom")}, '
       f'0 0 0 1.5px {C("glow-primary-ring")}, 0 6px 14px -4px {C("glow-primary-halo")}, 0 2px 2px {C("glow-primary-cast")}')
PAUSE = re.search(r' d="([^"]+)"', open('../icons/shipped/pause.svg').read()).group(1) if __import__('os').path.exists('../icons/shipped/pause.svg') else None

# 1 · the episode keeps playing, shrunk into the mini-player (part 45, same size and progress line)
def mini():
    art = e.MESH['weekly']
    btn = (b.icon('pause', 20, C('icon-default')) if PAUSE else '')
    return (f'<div layer-name="c:mini-player/playing" style="width:354px;height:64px;flex-shrink:0;position:relative;overflow:clip;display:flex;align-items:center;gap:{V("spacing-3")};'
            f'padding:0 {V("spacing-2")};border-radius:{V("radius-control")};background:{C("background-raised")};{SHADOW_RAISED}">'
            f'<div layer-name="artwork · mesh · weekly" style="width:44px;height:44px;flex-shrink:0;border-radius:{V("radius-control")};background-color:{art[0]};background-image:{art[1]}"></div>'
            f'<div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:{V("spacing-size-border-ring")}">'
            + _t('the week you started', 'text-md', 'text-primary', 'font-text', 'font-weight-medium', 'white-space:nowrap;overflow:hidden;text-overflow:ellipsis')
            + _t('your first episode · 4:24 left', 'text-sm', 'text-label', 'font-label') + '</div>'
            f'<div layer-name="pause" style="width:44px;height:44px;flex-shrink:0;border-radius:{V("radius-control")};background:{C("surface-wash")};display:flex;align-items:center;justify-content:center">{btn}</div>'
            f'<div layer-name="progress" style="position:absolute;left:0;bottom:0;height:2px;width:13%;background:{C("player-progress")}"></div></div>')

# 3 · benefit rows in north-star order; each drawing is a token shape (day one: shapes, never invented data)
def well(inner, extra=''):
    return (f'<div layer-name="drawing" style="width:44px;height:44px;flex-shrink:0;border-radius:{V("radius-default")};overflow:clip;position:relative;'
            f'display:flex;align-items:center;justify-content:center;{extra}">{inner}</div>')
def mesh(kind): return well('', f'background-color:{e.MESH[kind][0]};background-image:{e.MESH[kind][1]}')
MAP = well(f'<svg width="36" height="36" viewBox="0 0 36 36"><circle cx="18" cy="18" r="12" fill="none" stroke="{C("border-strong")}" stroke-width="1"/>'
           f'<circle cx="18" cy="18" r="4" fill="{C("text-primary")}"/><circle cx="29" cy="14" r="2.5" fill="{C("sky-500")}"/>'
           f'<circle cx="9" cy="25" r="2.5" fill="{C("green-600")}"/><circle cx="14" cy="7" r="2" fill="{C("amber-300")}"/></svg>', f'background:{C("surface-wash")}')
SAID = well(f'<div style="width:28px;display:flex;flex-direction:column;gap:{V("spacing-1")}">'
            f'<div style="height:5px;width:28px;border-radius:{V("radius-small")};background:{C("goal-said")}"></div>'
            f'<div style="height:5px;width:17px;border-radius:{V("radius-small")};background:{C("goal-did")}"></div></div>', f'background:{C("surface-wash")}')
TALK = well(f'<div style="width:30px;display:flex;flex-direction:column;gap:{V("spacing-1")}">'
            f'<div style="height:9px;width:20px;border-radius:{V("radius-small")};background:{C("background-raised")};box-shadow:0 0 0 0.5px {C("border-strong")}, 0 1px 2px {C("depth-shadow-cast")}"></div>'
            f'<div style="height:9px;width:22px;align-self:flex-end;border-radius:{V("radius-small")};background:{C("message-mine")};box-shadow:0 0 0 0.5px {C("border-strong")}"></div></div>', f'background:{C("surface-wash")}')
BENEFITS = [(mesh('brief'), 'a brief every morning', 'what moved since yesterday'),
            (MAP, 'the map of your life', 'the people and threads you return to'),
            (SAID, 'what you said vs what you did', 'your goals, checked against your days'),
            (mesh('weekly'), 'an episode every week', 'like this one, made from your week'),
            (TALK, 'a journal that talks back', 'talk or type; retro asks the next question')]
def benefit(d, title, line):
    return (f'<div layer-name="c:benefit-row" style="display:flex;align-items:center;gap:{V("spacing-4")};padding:{V("spacing-3")} 0">' + d
            + f'<div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:{V("spacing-size-border-ring")}">'
            + _t(title, 'text-body', 'text-primary', 'font-text', 'font-weight-medium', f'letter-spacing:{V("tracking-card")}') + _t(line, 'text-md', 'text-secondary') + '</div></div>')
def benefits():
    return (f'<div layer-name="benefits · scroll" style="display:flex;flex-direction:column;padding:0 {V("spacing-screen-margin")}">'
            + ''.join(benefit(*x) for x in BENEFITS) + '</div>')

# 4 · plans
def badge():
    return (f'<div layer-name="c:badge/save" style="position:absolute;top:-11px;left:50%;transform:translateX(-50%);padding:{V("spacing-size-border-ring")} {V("spacing-2")};'
            f'border-radius:{V("radius-control")};background:{C("background-raised")};box-shadow:inset 0 0 0 1px {C("accent-border")}, 0 2px 4px -1px {C("depth-shadow-cast")};'
            f'font-family:{V("font-mono")};font-size:{V("text-xs")};line-height:{V("leading-snug")};color:{C("accent-text")};white-space:nowrap">save 17%</div>')
def plan_label(top, sub, fg, sub_fg):
    return (f'<div style="display:flex;flex-direction:column;align-items:center;gap:{V("spacing-size-border-ring")}">'
            + _t(top, 'text-body', fg, 'font-text', 'font-weight-semibold') + _t(sub, 'text-sm', sub_fg, 'font-label') + '</div>')
YEARLY, MONTHLY = ('yearly · $199.99', '$16.67 a month'), ('monthly · $19.99', 'billed each month')
def plans_as_buttons():   # A · the spec: each plan is a button; yearly is the one lit object
    m = (f'<div layer-name="c:button/secondary/plan-monthly" style="flex:1;height:64px;display:flex;align-items:center;justify-content:center;border-radius:{V("radius-control")};'
         f'background:{C("surface-secondary-action")};box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, 0 0 0 1px {C("border-secondary-ring")}, 0 2px 3px {C("depth-shadow-cast")}">'
         + plan_label(*MONTHLY, 'text-primary', 'text-label') + '</div>')
    y = (f'<div layer-name="c:button/lit/plan-yearly" style="flex:1;height:64px;position:relative;display:flex;align-items:center;justify-content:center;border-radius:{V("radius-control")};{LIT}">'
         + plan_label(*YEARLY, 'glow-primary-foreground', 'glow-primary-foreground') + badge() + '</div>')
    return f'<div layer-name="plan pair" style="display:flex;gap:{V("spacing-3")}">{m}{y}</div>'
def plan_card(top, sub, selected):
    ring = (f'box-shadow:inset 0 0 0 1.5px {C("accent-border")}, 0 2px 3px {C("depth-shadow-cast")}' if selected else SHADOW_RAISED)
    # no tick: it collided with the price; the 1.5 accent ring and the badge carry the selection (not colour alone)
    tick = (f'<div style="position:absolute;top:{V("spacing-2")};right:{V("spacing-2")};width:20px;height:20px;border-radius:{V("radius-control")};background:{C("accent-default")};'
            f'display:flex;align-items:center;justify-content:center">{b.icon("check", 14, C("text-on-accent"))}</div>') if selected else ''
    return (f'<div layer-name="c:plan-card/{"selected" if selected else "rest"}" style="flex:1;height:72px;position:relative;display:flex;align-items:center;justify-content:center;'
            f'border-radius:{V("radius-card")};background:{C("background-raised")};{ring}">' + plan_label(top, sub, 'text-primary', 'text-label') + (badge() if selected else '') + '</div>')
def plans_then_subscribe():   # B · the mid-fi: choose a plan (yearly preselected), then one lit subscribe
    pair = f'<div layer-name="plan pair" style="display:flex;gap:{V("spacing-3")}">' + plan_card(*MONTHLY, False) + plan_card(*YEARLY, True) + '</div>'
    sub = (f'<div layer-name="c:button/lit/subscribe" style="height:{V("spacing-size-control-hero")};display:flex;align-items:center;justify-content:center;border-radius:{V("radius-control")};{LIT}">'
           + _t('subscribe · $199.99 a year', 'text-body', 'glow-primary-foreground', 'font-text', 'font-weight-semibold') + '</div>')
    return pair + sub

# 5 · not now · restore · privacy · terms, each in a 44 hit area
def links():
    one = lambda s, c: (f'<div style="height:44px;display:flex;align-items:center;padding:0 {V("spacing-2")}">'
                        + _t(s, 'text-sm', c, 'font-label', 'font-weight-medium' if c == 'text-link' else 'font-weight-regular') + '</div>')
    return (f'<div layer-name="links" style="display:flex;justify-content:center;gap:{V("spacing-2")}">'
            + one('not now', 'text-link') + one('restore', 'text-label') + one('privacy', 'text-label') + one('terms', 'text-label') + '</div>')

def phone(decision, name):
    status = t.STATUS.replace(' clip-rule="evenodd" style="opacity: .35" ', ' fill-opacity="0.35" ').replace(' style="opacity: .35" ', ' fill-opacity="0.35" ').replace(' clip-rule="evenodd" ', ' ')
    top = (f'<div layer-name="top" style="display:flex;flex-direction:column;gap:{V("spacing-6")};padding:{V("spacing-2")} {V("spacing-screen-margin")} {V("spacing-2")}">'
           + mini() + f'<div style="font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-title")};font-size:{V("text-3xl")};line-height:{V("leading-tight")};'
           f'letter-spacing:{V("tracking-title")};color:{C("text-primary")};text-wrap:balance">hear the rest, and one every week.</div></div>')
    bottom = (f'<div layer-name="decision · thumb zone" style="position:relative;display:flex;flex-direction:column;gap:{V("spacing-3")};padding:{V("spacing-4")} {V("spacing-screen-margin")} {V("spacing-6")};background:{C("background-canvas")}">'
              f'<div layer-name="fade" style="position:absolute;left:0;right:0;top:-64px;height:64px;background:linear-gradient(180deg, transparent, {C("background-canvas")})"></div>'
              + decision + links() + '</div>')
    return (f'<div layer-name="{name}" style="width:402px;height:874px;flex-shrink:0;position:relative;overflow:clip;display:flex;flex-direction:column;'
            f'border-radius:{V("radius-sheet")};background:{C("background-canvas")};box-shadow:inset 0 0 0 1px {C("border-subtle")}">'
            + status + top + f'<div layer-name="middle" style="flex:1 1 0%;min-height:0;overflow:clip;padding-top:{V("spacing-4")}">' + benefits() + '</div>' + bottom + '</div>')

A = phone(plans_as_buttons(), 'ON-12 · A · the plans are the buttons')
B = phone(plans_then_subscribe(), 'ON-12 · B · choose, then subscribe')
HTML = card(6, 'paywall · choosing a plan',
    'how do you pick a plan and pay?',
    'the paywall rises out of your first episode (it keeps playing in the mini-player): one line, five things you get, then the decision in the thumb zone.',
    'yearly is the suggested plan; "not now" and "restore" are always visible; prices come from the App Store, never typed in.',
    'the spec says the two plans are the buttons (yearly lit); the mid-fi says choose a plan, then one lit "subscribe". they can\'t both be right.',
    [option('A', 'the plans are the buttons', A, 'one tap to buy; yearly is lit, so the suggestion is obvious without a "selected" state', 'a big lit button with a price on it reads as pushy; tapping the wrong plan opens the App Store sheet for it', ('lean',)),
     option('B', 'choose, then subscribe', B, 'calm: you see both, the choice is reversible, and the lit button says exactly what you\'ll pay', 'one more tap, and 80 more of the screen, so the benefits get less room (on SE they scroll sooner)', ())],
    'A. the App Store sheet already confirms the price, so a selection step adds a tap without adding safety; A keeps more of the screen for what you get, which is the point of the page.')
HTML = HTML.replace('width:440px;flex-shrink:0', 'width:442px;flex-shrink:0')
open('p46_paywall.html', 'w').write(HTML)
