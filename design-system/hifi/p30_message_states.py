from review import *
import importlib.util
# M3 · message · every state (craft §11), assembled only from the approved part 08 pieces (master: c · conversation).
# One column per state: heading, the state on a 390 page strip, a plain caption. States that can't be drawn say why.
spec = importlib.util.spec_from_file_location('p08', 'p08_conversation.py'); p08 = importlib.util.module_from_spec(spec); spec.loader.exec_module(p08)
icon, label = p08.icon, p08.label

def bubble_style(extra=''):
    # each corner set on its own: Paper renders the four-value radius shorthand square
    return (f'align-self:flex-end;padding:{V("spacing-3")} {V("spacing-4")};background:{C("message-mine")};'
            f'border-top-left-radius:{V("radius-message")};border-top-right-radius:{V("radius-message")};'
            f'border-bottom-left-radius:{V("radius-message")};border-bottom-right-radius:{V("spacing-size-border-inset")};{extra}')
def body(s, w, size='text-body', lead='leading-snug', colour='text-primary', extra=''):
    return (f'<div style="width:{w}px;font-family:{V("font-text")};font-size:{V(size)};letter-spacing:{V("tracking-card")};'
            f'line-height:{V(lead)};color:{C(colour)};{extra}">{s}</div>')
def mine(s, w, state='rest', bubble_extra='', note=''):
    return (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-1")}">'
            f'<div layer-name="c:message/mine/{state}" style="{bubble_style(bubble_extra)}">{body(s, w)}</div>{note}</div>')
def theirs(s, state='rest', size='text-body', lead='leading-normal', w=296, extra=''):
    return f'<div layer-name="c:message/theirs/{state}" style="display:flex">{body(s, w, size, lead, extra=extra)}</div>'
def note(s, colour, ic=None):
    return (f'<div style="align-self:flex-end;display:flex;align-items:center;gap:{V("spacing-1")}">'
            + (icon(ic, colour, 12) if ic else '') + label(s, colour) + '</div>')
def page(inner):
    return (f'<div layer-name="page strip" style="width:390px;box-sizing:border-box;display:flex;flex-direction:column;gap:{V("spacing-6")};'
            f'padding:{V("spacing-6")};background:{C("background-canvas")};border-radius:{V("radius-card")};box-shadow:inset 0 0 0 1px {C("border-subtle")}">{inner}</div>')
def column(name, inner, caption):
    return (f'<div layer-name="state · {name}" style="width:390px;display:flex;flex-direction:column;gap:{V("spacing-3")}">'
            f'<div style="font-family:{V("font-label")};font-size:{V("text-md")};font-weight:{V("font-weight-medium")};line-height:{V("leading-snug")};color:{C("text-primary")}">{name}</div>'
            f'{page(inner)}<div style="width:390px;font-family:{V("font-text")};font-size:{V("text-md")};line-height:{V("leading-normal")};color:{C("text-secondary")}">{caption}</div></div>')

Q = "third monday like that. what's different about mondays?"
A = "i think it's the 9am standup. i dread it."
RAISED = (f'background:{C("background-raised")};box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, 0 0 0 0.5px {C("depth-stroke-outer")}, '
          f'0 1px 2px {C("depth-shadow-contact")}, 0 12px 28px -12px {C("depth-shadow-cast")}, 0 24px 48px -16px {C("depth-shadow-ambient")}')
def menu_row(t, chevron=False):
    return (f'<div layer-name="row" style="height:44px;display:flex;align-items:center;gap:{V("spacing-3")};padding:0 {V("spacing-3")};border-radius:{V("radius-control")}">'
            f'<div style="flex:1;font-family:{V("font-label")};font-size:{V("text-md")};font-weight:{V("font-weight-medium")};line-height:{V("leading-snug")};color:{C("text-primary")}">{t}</div>'
            + (icon('chevron-right', 'icon-muted', 16) if chevron else '') + '</div>')
PRESSED = (f'<div layer-name="c:message/theirs/pressed" style="display:flex;flex-direction:column;gap:{V("spacing-2")}">'
           f'<div style="align-self:flex-start;padding:{V("spacing-3")} {V("spacing-4")};border-radius:{V("radius-card")};{RAISED}">{body(Q, 264, lead="leading-normal")}</div>'
           f'<div layer-name="c:menu/message/open" style="width:220px;display:flex;flex-direction:column;padding:{V("spacing-1")};border-radius:{V("radius-card")};{RAISED}">'
           + menu_row('copy') + menu_row('correct this') + menu_row('why you said this', True) + '</div></div>')
DOTS = (f'<div layer-name="c:message/theirs/loading" style="display:flex;gap:{V("spacing-1")};height:26px;align-items:center">'
        + ''.join(f'<div style="width:6px;height:6px;border-radius:{V("radius-control")};background:{C("text-label")}"></div>' for _ in range(3)) + '</div>')
ARRIVE = (f'<div layer-name="c:message/theirs/arriving" style="display:flex;flex-direction:column">'
          + body("third monday like that.", 296, lead='leading-normal')
          + body("what's different about mondays?", 296, lead='leading-normal', extra=f'filter:blur(1px);opacity:{V("opacity-pending")}') + '</div>')
RM = (f'<div layer-name="c:message/theirs/arriving-reduced" style="display:flex;flex-direction:column">'
      + body("third monday like that.", 296, lead='leading-normal')
      + body("what's different about mondays?", 296, lead='leading-normal', extra=f'opacity:{V("opacity-pending")}') + '</div>')
AX3 = (f'<div layer-name="c:message/mine/ax3" style="{bubble_style("align-self:stretch")}">{body(A, 310, "text-ax3-body", "leading-ax3-body")}</div>'
       + theirs(Q, 'ax3', 'text-ax3-body', 'leading-ax3-body', 342))

cols = [
    column('rest', theirs(Q) + mine(A, 232), "Retro's words sit unboxed on the page; yours are in the wash bubble with the small corner on your side."),
    column('arriving · Retro is speaking', ARRIVE, "Retro's words stream in a line at a time; each line resolves from a soft blur, so you read along instead of waiting."),
    column('loading', DOTS, 'Only if the first words take more than a beat: three quiet dots, never for more than 1.2 seconds. Then words stream instead.'),
    column('sending', theirs(Q) + mine(A, 232, 'sending', f'opacity:{V("opacity-pending")}'), 'Yours, on its way: the bubble sits a little faint until it lands. No spinner, no "sending" word.'),
    column('not sent', mine(A, 232, 'failed', note=note('not sent · tap to retry', 'status-danger-text', 'retry')), 'It failed: your words stay where you put them, with one plain line under them. Tap to send again.'),
    column('offline', mine(A, 232, 'queued', note=note("will send when you're back online", 'text-label', 'offline')), "No connection: your message waits on the phone and goes when you're back. Nothing is lost."),
    column('pressed · long press', PRESSED, 'Hold any line of Retro\'s: it lifts, and a small menu offers copy, correct this, and why it said this.'),
    column('empty · a new conversation', theirs("what's on your mind today?"), "Never a blank screen: a new conversation opens on Retro's first line."),
    column('largest text (accessibility 3)', AX3, 'At the largest text size the words grow to 40, and your bubble takes the full width so nothing is cramped.'),
    column('increase contrast', theirs(Q) + mine(A, 232, 'contrast', f'box-shadow:inset 0 0 0 1px {C("border-control")}'), 'With Increase Contrast on, your bubble gets a 1pt edge so its shape holds without relying on the wash.'),
    column('reduce motion', RM, 'With Reduce Motion on, lines simply fade in (140ms), with no blur.'),
]
NOT_DRAWN = (f'<div layer-name="states not drawn, and why" style="width:390px;display:flex;flex-direction:column;gap:{V("spacing-2")}">'
             f'<div style="font-family:{V("font-label")};font-size:{V("text-md")};font-weight:{V("font-weight-medium")};color:{C("text-primary")}">not drawn, and why</div>'
             + ''.join(f'<div style="width:390px;font-family:{V("font-text")};font-size:{V("text-md")};line-height:{V("leading-normal")};color:{C("text-secondary")}">{s}</div>' for s in [
                 'focused: iOS draws the Full Keyboard Access ring itself; on a board it reads as "selected" (your call, 20 Oct).',
                 'disabled: a message is never disabled.',
                 'reduce transparency: nothing in a message is translucent, so nothing changes.',
                 'dark: drawn in M12 with the dark token pairs (light first, then dark, your rule).']) + '</div>')
board = f'<div layer-name="states grid" style="display:flex;flex-wrap:wrap;gap:{V("spacing-10")};align-items:flex-start;width:1720px">' + ''.join(cols) + NOT_DRAWN + '</div>'
open('p30_message_states.html', 'w').write(board)
