from review import *
import importlib.util
# M3 · voice composer · every state (craft §11), assembled only from the approved part 07 master (c · voice composer).
def load(n, f):
    s = importlib.util.spec_from_file_location(n, f); m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m
p07 = load('p07', 'p07_composer.py'); p30 = load('p30', 'p30_message_states.py')
bar, bars, text, button, icon = p07.bar, p07.bars, p07.text, p07.button, p07.icon
column = p30.column

def dots():
    return (f'<div layer-name="thinking" style="display:flex;gap:{V("spacing-1")};height:20px;align-items:center;flex-shrink:0">'
            + ''.join(f'<div style="width:5px;height:5px;border-radius:{V("radius-control")};background:{C("voice-listening")}"></div>' for _ in range(3)) + '</div>')
def well(n, look, colour='icon-default', extra=''):
    # a plain 32 well whose look is a token, for states the part 07 button() tiers don't cover (pressed, disabled)
    guide = f'<div layer-name="hit area 44" style="position:absolute;left:-6px;top:-6px;width:44px;height:44px;outline:1px dashed {C("text-link")};outline-offset:-1px"></div>'
    return (f'<div layer-name="c:icon-button/{n}" style="position:relative;width:32px;height:32px;flex-shrink:0;border-radius:{V("radius-control")};{look}display:flex;align-items:center;justify-content:center;{extra}">'
            f'{icon(n, colour)}{guide}</div>')
def meter():
    # Reduce Motion: the five bouncing bars become one steady level meter
    return (f'<div layer-name="level meter" style="width:40px;height:4px;flex-shrink:0;border-radius:{V("radius-control")};background:{C("surface-wash")};display:flex">'
            f'<div style="width:24px;height:4px;border-radius:{V("radius-control")};background:{C("voice-listening")}"></div></div>')
def strip(inner):
    return inner  # p30.column already places the state on its canvas strip

THINK = bar('thinking', (dots() + text('thinking…', 'text-tertiary'), button('mic-off', 'wash')), listening=True)
PRESSED = bar('muted-empty-pressed', (text('message retro…', 'text-tertiary'), well('mic', f'background:{C("surface-wash-pressed")};')))
NOMIC = bar('disabled-no-mic', (text('type, or allow the mic in settings', 'text-tertiary'), well('mic', f'background:{C("surface-wash")};', extra=f'opacity:{V("opacity-disabled")}')))
ERROR = bar('error', (icon('alert', 'status-warning-text', 18) + text("i didn't catch that, try again", 'status-warning-text'), button('mic', 'wash')), listening=True)
OFFLINE = bar('offline', (icon('offline', 'icon-muted', 18) + text("talking needs a connection. type, and it sends when you're back", 'text-tertiary'), well('send', f'background:{C("surface-wash")};', extra=f'opacity:{V("opacity-disabled")}')))
AX3 = (f'<div layer-name="c:voice-composer/ax3" style="width:342px;min-height:56px;box-sizing:border-box;display:flex;align-items:flex-end;gap:{V("spacing-3")};'
       f'padding:{V("spacing-3")} {V("spacing-3")} {V("spacing-3")} {V("spacing-5")};border-radius:{V("radius-composer")};background:{C("background-raised")};box-shadow:{p07.RAISED_STACK}">'
       f'<div style="width:254px;font-family:{V("font-text")};font-size:{V("text-ax3-body")};letter-spacing:{V("tracking-card")};line-height:{V("leading-ax3-body")};color:{C("text-primary")}">i think it\'s the 9am standup. i dread it.</div>'
       f'{button("send", "lit", "glow-primary-foreground")}</div>')
IC = bar('increase-contrast', (text('message retro…', 'text-secondary'), button('mic', 'wash')), extra_shadow=f'inset 0 0 0 1px {C("border-control")}, ')
RM = bar('listening-reduced', (meter() + text('listening…', 'text-tertiary'), button('mic-off', 'wash')), listening=True)

cols = [
    column('thinking · after you stop', THINK, "You've stopped talking and Retro is working out its reply: the bars settle into three dots. Your words stay on the page."),
    column('pressed · the well', PRESSED, 'Touching the mic well darkens it a step (and it shrinks a touch, which Paper can\'t show). It answers on touch down.'),
    column('no mic permission', NOMIC, "If the mic isn't allowed, the bar says so in plain words and you can still type. The mic well is faded, not hidden."),
    column("didn't catch that", ERROR, "If speech didn't come through, the words clear and the bar says so, in warning ink. It's still listening, so just try again."),
    column('offline', OFFLINE, "No connection: talking can't work, typing still can. What you type waits and sends when you're back."),
    column('largest text (accessibility 3)', AX3, 'At the largest text size your words grow to 40 and the bar grows with them, up to 40% of the screen, then scrolls.'),
    column('increase contrast', IC, 'With Increase Contrast on, the bar gets a 1pt control edge and the placeholder a darker grey.'),
    column('reduce motion', RM, 'With Reduce Motion on, the five moving bars become one steady level meter, and your words appear without blur.'),
]
NOT_DRAWN = (f'<div layer-name="states not drawn, and why" style="width:390px;display:flex;flex-direction:column;gap:{V("spacing-2")}">'
             f'<div style="font-family:{V("font-label")};font-size:{V("text-md")};font-weight:{V("font-weight-medium")};color:{C("text-primary")}">already approved, and not drawn</div>'
             + ''.join(f'<div style="width:390px;font-family:{V("font-text")};font-size:{V("text-md")};line-height:{V("leading-normal")};color:{C("text-secondary")}">{s}</div>' for s in [
                 'listening, speaking, muted and empty, muted and typing: the four approved states, on the master board (c · voice composer).',
                 'focused: iOS draws the Full Keyboard Access ring itself (your call, 20 Oct).',
                 'loading: not a state here. Listening with no words yet is the empty state.',
                 'reduce transparency: the bar is opaque, so nothing changes.',
                 'dark: drawn in M12 with the dark token pairs.']) + '</div>')
open('p31_composer_states.html', 'w').write(
    f'<div layer-name="states grid" style="display:flex;flex-wrap:wrap;gap:{V("spacing-10")};align-items:flex-start;width:1720px">' + ''.join(cols) + NOT_DRAWN + '</div>')
