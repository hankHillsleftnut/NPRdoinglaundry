from review import *
import json
# Part 08 · conversation · one Journal exchange, every message part in place (M2: your message, voice note, Retro's reply,
# the "because" line, a failed send, the guess card). Keeps the language the founder called "sexy as hell" (c-ior563):
# Retro unboxed beside the mark, yours in a wash bubble with a 6 tail corner. Two versions differ only in Retro's face.
O = json.load(open('../icons/outlined-20.json'))
def icon(n, colour, size=16):
    return (f'<svg layer-name="c:icon/{n}" width="{size}" height="{size}" viewBox="0 0 24 24" style="display:inline-block;flex-shrink:0">'
            f'<path fill="{C(colour)}" fill-rule="evenodd" d="{O[n]}"/></svg>')
MARK = (f'<div layer-name="c:the-mark/22" style="width:22px;height:22px;flex-shrink:0;border-radius:{V("radius-control")};background:{C("surface-secondary-action")};'
        f'box-shadow:inset 0 0 0 1px {C("depth-stroke-inner-top")}, 0 0 0 1px {C("border-secondary-ring")}, 0 2px 3px {C("depth-shadow-cast")}, 0 0.5px 1px {C("depth-shadow-contact")}"></div>')
def label(s, colour='text-label', extra=''):
    return f'<div style="font-family:{V("font-label")};font-size:{V("text-sm")};line-height:{V("leading-snug")};color:{C(colour)};{extra}">{s}</div>'
def retro(s, inky, mark=True, because=None):
    face = (f'font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-card")};font-size:{V("text-lg")};line-height:{V("leading-snug")};letter-spacing:{V("tracking-tight")}'
            if inky else f'font-family:{V("font-text")};font-size:{V("text-body")};letter-spacing:{V("tracking-card")};line-height:{V("leading-normal")}')
    b = (f'<div layer-name="because" style="display:flex;align-items:center;gap:{V("spacing-1")}">{label(because)}{icon("chevron-right", "text-label", 12)}</div>' if because else '')
    # founder 20 Oct (c-p8h9oc): "there should not be a icon here" — Retro's lines carry no mark; unboxed text is the tell
    return (f'<div layer-name="c:message/theirs/rest" style="display:flex;align-items:flex-start">'
            f'<div style="width:296px;display:flex;flex-direction:column;gap:{V("spacing-2")}"><div style="width:296px;{face};color:{C("text-primary")}">{s}</div>{b}</div></div>')
def mine(s, state=None, w=None):
    note = ''
    if state == 'failed':
        note = label('not sent · tap to retry', 'status-danger-text', 'align-self:flex-end')
    bubble = (f'<div layer-name="c:message/mine/{state or "rest"}" style="align-self:flex-end;padding:{V("spacing-3")} {V("spacing-4")};background:{C("message-mine")};'
              f'border-radius:{V("radius-message")} {V("radius-message")} {V("spacing-size-border-inset")} {V("radius-message")}">'
              f'<div style="width:{w}px;font-family:{V("font-text")};font-size:{V("text-body")};letter-spacing:{V("tracking-card")};line-height:{V("leading-snug")};color:{C("text-primary")}">{s}</div></div>')
    return f'<div style="display:flex;flex-direction:column;gap:{V("spacing-1")}">{bubble}{note}</div>'
def voice_note():
    heights = [6, 10, 16, 12, 20, 14, 8, 12, 18, 10, 6, 14, 10, 6, 12, 8]
    wave = ''.join(f'<div style="width:{V("spacing-size-voice-bar-width")};height:{h}px;border-radius:{V("radius-control")};background:{C("text-secondary" if i < 7 else "text-tertiary")}"></div>' for i, h in enumerate(heights))
    return (f'<div layer-name="c:message/mine/voice" style="align-self:flex-end;display:flex;align-items:center;gap:{V("spacing-3")};padding:{V("spacing-2")} {V("spacing-4")} {V("spacing-2")} {V("spacing-2")};'
            f'background:{C("message-mine")};border-radius:{V("radius-message")} {V("radius-message")} {V("spacing-size-border-inset")} {V("radius-message")}">'
            f'<div style="width:32px;height:32px;border-radius:{V("radius-control")};background:{C("background-raised")};box-shadow:0 0 0 0.5px {C("depth-stroke-outer")}, 0 1px 2px {C("depth-shadow-contact")};display:flex;align-items:center;justify-content:center">{icon("play", "icon-default")}</div>'
            f'<div style="display:flex;align-items:center;gap:{V("spacing-size-voice-bar-gap")};height:20px">{wave}</div>'
            f'<div style="font-family:{V("font-mono")};font-size:{V("text-sm")};color:{C("text-label")}">1:42</div></div>')
def day(s):
    return f'<div style="display:flex;justify-content:center">{label(s, extra="font-weight:" + V("font-weight-medium"))}</div>'
pill = lambda t, ic=None: (f'<div layer-name="c:pill/neutral/rest" style="height:36px;display:flex;align-items:center;gap:{V("spacing-2")};padding:0 {V("spacing-4")};border-radius:{V("radius-control")};background:{C("surface-wash")}">'
                           + (icon(ic, "icon-default") if ic else '') + f'<div style="font-family:{V("font-label")};font-size:{V("text-md")};font-weight:{V("font-weight-medium")};color:{C("text-primary")}">{t}</div></div>')
GUESS = (f'<div layer-name="c:guess-card/open" style="display:flex;flex-direction:column;gap:{V("spacing-3")};padding:{V("spacing-4")};border-radius:{V("radius-card")};'
         f'background:{C("inference-surface")};outline:1px dashed {C("inference-border")};outline-offset:-1px">'
         f'<div style="display:flex;align-items:center;gap:{V("spacing-2")}"><div style="width:{V("spacing-size-step-dot")};height:{V("spacing-size-step-dot")};border-radius:{V("radius-control")};background:{C("inference-marker")}"></div>{label("a guess")}</div>'
         f'<div style="width:310px;font-family:{V("font-text")};font-size:{V("text-body")};letter-spacing:{V("tracking-card")};line-height:{V("leading-snug")};color:{C("text-primary")}">Mondays are harder because of the 9am standup, not the work itself.</div>'
         + label('from your last 3 mondays · calendar · fairly sure')
         + f'<div style="display:flex;gap:{V("spacing-2")}">{pill("that\'s right", "check")}{pill("not quite")}</div></div>')
def thread(inky):
    parts = [day('yesterday'), voice_note(), mine('slept badly, long day of meetings', w=232),
             retro("third monday like that. what's different about mondays?", inky, because='from your last 3 mondays'),
             day('today'), mine("i think it's the 9am standup. i dread it.", w=232),
             retro('want me to keep an eye on how mondays go for the next few weeks?', inky), GUESS, mine('yes', 'failed', w=26)]
    return (f'<div layer-name="phone · thread" style="width:390px;flex-shrink:0;display:flex;flex-direction:column;gap:{V("spacing-6")};padding:{V("spacing-6")};'
            f'background:{C("background-canvas")};border-radius:{V("radius-sheet")};box-shadow:inset 0 0 0 1px {C("border-subtle")}">' + ''.join(parts) + '</div>')
open('p08_a.html', 'w').write(tile(thread(False), 'A · Retro in SF Pro 17/26 beside the mark (the version you called "sexy as hell")'))
open('p08_b.html', 'w').write(tile(thread(True), 'B · Retro in the inky face 18 (as the mid-fi planned), so its voice reads apart from yours'))
